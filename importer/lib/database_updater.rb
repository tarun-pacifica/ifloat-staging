class DatabaseUpdater
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row operation error)
  
  def initialize(classes, object_catalogue)
    @classes = classes
    @objects = object_catalogue
    
    @adapter = DataMapper.repository(:default).adapter
    @errors = []
  end
  
  def scan_db(klass)
    query = <<-SQL
      CREATE TEMPORARY TABLE IF NOT EXISTS #{klass.storage_name}_md5s (
        id INT(10) unsigned PRIMARY KEY,
        pk_md5 VARCHAR(32) NOT NULL,
        value_md5 VARCHAR(32)
      ) ENGINE=MEMORY DEFAULT CHARSET=utf8
    SQL
    @adapter.execute(query)
    
    pks_vks = ObjectRef.keys_for(klass)
    return if pks_vks.first.nil?
    
    relationships = klass.relationships
    pk_fields, value_fields = pks_vks.each_with_index.map do |keys, i|
      components = keys.map do |key|
        rel = relationships[key]
        field =
          if rel.nil? then "t1.#{key}"
          else "(SELECT pk_md5 FROM #{rel.parent_model.storage_name}_md5s WHERE id = t1.#{rel.child_key.first.name})"
          end
        "IFNULL(#{field}, '')"
      end
      
      components.unshift("'#{klass}'") if i == 0
      components.empty? ? "MD5('')" : "MD5(CONCAT(#{components.join(",'::',")}))"
    end
    
    query = <<-SQL
      INSERT INTO #{klass.storage_name}_md5s
      SELECT id, #{pk_fields} AS pk_md5, #{value_fields} AS value_md5
      FROM #{klass.storage_name} t1
    SQL
    query += "WHERE type = '#{klass}'" if klass.properties.named?(:type)
    @adapter.execute(query) # TODO: cope explicitly with table full errors
    
    valid_pk_md5s_seen = []
    query = "SELECT * FROM #{klass.storage_name}_md5s"
    query += " WHERE id IN (SELECT id FROM #{klass.storage_name} WHERE type = '#{klass}')" if klass.properties.named?(:type)
    @adapter.select(query).each do |record|
      id, pk_md5, db_value_md5 = record.id, record.pk_md5, record.value_md5
      
      value_md5 = @objects.value_md5_for(pk_md5)
      if value_md5.nil?
        puts "delete #{pk_md5} (#{id})"
        break
      elsif value_md5 != db_value_md5
        puts "update #{pk_md5} (#{id}): #{db_value_md5} -> #{value_md5}"
        valid_pk_md5s_seen << pk_md5
        break
      end
    end
    valid_pk_md5s_seen
  end
  
  def update
    DataMapper.repository(:default) do
      transaction = DataMapper::Transaction.new(@adapter)
      transaction.begin
      @adapter.push_transaction(transaction)
      
      @adapter.execute("SET max_heap_table_size = 256*1024*1024")
      valid_pk_md5s_seen = @classes.map(&method(:scan_db)).flatten.to_set
      # do inserts
      
      # keys = @objects.keys
      # begin tran
      # obsolete = db_keys - keys => delete
      # inserts  = keys - db_keys => insert as chain of dependency - so will need to maintain a pkmd5=>ID lookup table in mem
      # updates  = (walk remainder and note diff val md5s?) - use lookup table here as well
      # end tran
      
      @adapter.pop_transaction
      if @errors.empty? then transaction.commit
      else transaction.rollback
      end
    end
  end
end
