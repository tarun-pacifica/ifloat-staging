class DatabaseUpdater
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row operation error)
  
  def initialize(classes, object_catalogue)
    @classes = classes
    @objects = object_catalogue
    
    @adapter = DataMapper.repository(:default).adapter
    @db_ids_by_pk_md5 = {} # TODO: consider making this an OM hash table (conserve mem) - test with a full insert set
    @db_value_md5s_by_pk_md5 = {} # ditto
    @errors = []
  end
  
  def gather_db_keys
    @classes.each do |klass|
      pks_vks = ObjectRef.keys_for(klass)
      next if pks_vks.first.nil?
      
      child_keys_by_rel_name = Hash[klass.relationships.map { |name, rel| [name.to_sym, rel.child_key.first.name] }]
      pk_fields, value_fields = pks_vks.map do |keys|
        keys.map do |key|
          key = (child_keys_by_rel_name[key] || key)
          "IFNULL(#{key}, '')"
        end.join(",'::',")
      end
      
      query = "SELECT id, MD5(CONCAT(#{pk_fields})) AS pk_md5"
      query += (value_fields.empty? ? ", NULL AS value_md5" : ", MD5(CONCAT(#{value_fields})) AS value_md5")
      query += " FROM #{klass.storage_name}"
      query += " WHERE type = '#{klass}'" if klass.properties.named?(:type)
      
      @adapter.select(query).each do |record|
        @db_ids_by_pk_md5[record.pk_md5] = record.id
        @db_value_md5s_by_pk_md5[record.pk_md5] = record.value_md5
      end
    end
  end
  
  def update
    DataMapper.repository(:default) do
      transaction = DataMapper::Transaction.new(@adapter)
      transaction.begin
      @adapter.push_transaction(transaction)
      
      gather_db_keys
      
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
