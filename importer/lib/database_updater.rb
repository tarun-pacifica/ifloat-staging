class DatabaseUpdater
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row error)
  
  def initialize(classes, csv_catalogue, object_catalogue)
    @classes = classes
    @csvs = csv_catalogue
    @objects = object_catalogue
    
    @adapter = DataMapper.repository(:default).adapter
    @errors = []
  end
  
  def update
    DataMapper.repository(:default) do
      transaction = DataMapper::Transaction.new(@adapter)
      transaction.begin
      @adapter.push_transaction(transaction)
      
      @adapter.execute("SET max_heap_table_size = 256*1024*1024")
      md5_tables = @classes.map(&method(:md5_table)).uniq
      md5_tables.each do |table|
        @adapter.execute("DROP TABLE IF EXISTS #{table}")
        @adapter.execute <<-SQL
          CREATE TABLE #{table} (
            id INT(10) unsigned PRIMARY KEY,
            ref VARCHAR(32) NOT NULL,
            value_md5 VARCHAR(32),
            INDEX(ref)
          ) ENGINE=MEMORY DEFAULT CHARSET=utf8
        SQL
      end
      
      @classes.each(&method(:update_class))
      
      md5_tables.each { |table| @adapter.execute("DROP TABLE IF EXISTS #{table}") }
      
      @adapter.pop_transaction
      if @errors.empty? then transaction.commit
      else transaction.rollback
      end
    end
  end
  
  
  private
  
  def build_md5_report(klass)
    pk_fields, value_fields = build_md5_report_fields(klass)
    return false if pk_fields.nil?
    
    query = <<-SQL
      INSERT INTO #{md5_table(klass)}
      SELECT id, #{pk_fields} AS ref, #{value_fields} AS value_md5
      FROM #{klass.storage_name} t1
      WHERE id NOT IN (SELECT id FROM #{md5_table(klass)})
    SQL
    query += "AND type = '#{klass}'" if klass.properties.named?(:type)
    @adapter.execute(query) # TODO: cope explicitly with table full errors
    true
  end
  
  def build_md5_report_fields(klass)
    pks_vks = ObjectRef.keys_for(klass)
    return [nil, nil] if pks_vks.first.nil?
    
    relationships = klass.relationships
    pks_vks.each_with_index.map do |keys, i|
      components = keys.map do |key|
        rel = relationships[key]
        field =
          if rel.nil? then "t1.#{key}"
          else "(SELECT ref FROM #{md5_table(rel.parent_model)} WHERE id = t1.#{rel.child_key.first.name})"
          end
        "IFNULL(#{field}, '')"
      end
      
      components.unshift("'#{klass}'") if i == 0
      components.empty? ? "MD5('')" : "MD5(CONCAT(#{components.join(",'::',")}))"
    end
  end
  
  def delete_and_update_from_db_md5_report(klass)
    to_destroy_ids = []
    to_update_ids_by_ref = {}
    valid_refs_seen = []
    
    query = "SELECT * FROM #{md5_table(klass)}"
    query += " WHERE id IN (SELECT id FROM #{klass.storage_name} WHERE type = '#{klass}')" if klass.properties.named?(:type)
    @adapter.select(query).each do |record|
      id, ref, db_value_md5 = record.id, record.ref, record.value_md5
      
      value_md5 = @objects.value_md5_for(ref)
      if value_md5.nil?
        to_destroy_ids << id
      elsif value_md5 != db_value_md5
        to_update_ids_by_ref[ref] = id
      else
        valid_refs_seen << ref
      end
    end
    
    to_destroy_ids.each_slice(1000) { |ids| klass.all(:id => ids).destroy! }
    puts " --- destroyed #{to_destroy_ids.size}" unless to_destroy_ids.empty?
    
    to_update_ids_by_ref.values.each_slice(1000) { |ids| klass.all(:id => ids).destroy! }
    puts " --- destroyed #{to_update_ids_by_ref.size} for re-insertion" unless to_update_ids_by_ref.empty?
    
    [to_update_ids_by_ref, valid_refs_seen]
  end
  
  # TODO: need actual asset records in order to upload images?
  def insert_missing_refs(klass, to_update_ids_by_ref, valid_refs_seen)
    to_insert_refs = []
    
    @objects.queue_get("refs_by_class", klass) do |_, refs|
      obsolete_refs = []
      (refs - valid_refs_seen).each do |ref|
        object = @objects.data_for(ref)
        (object.nil? ? obsolete_refs : to_insert_refs) << ref
      end
      obsolete_refs
    end
    
    relationships = klass.relationships
    property_names_by_child_key = Hash[relationships.map { |name, rel| [rel.child_key.first.name, name.to_sym] }]
    
    db_properties_with_local_properties = klass.properties.map do |property|
      n = property.name
      [n.to_s, property_names_by_child_key[n] || n]
    end.compact
    column_names, local_symbols = db_properties_with_local_properties.transpose
    
    column_names_list = column_names.map(&@adapter.method(:quote_name)).join(", ")
    bind_parts = local_symbols.map do |sym|
      rel = relationships[sym]
      rel.nil? ? "?" : "(SELECT id FROM #{md5_table(rel.parent_model)} WHERE ref = ?)"
    end
    bind_set = "(#{bind_parts.join(', ')})"
    
    error_count = 0
    inserted_count = 0
    
    to_insert_refs.each_slice(1000) do |refs|
      bind_sets = []
      bind_values = []
      
      refs.each do |ref|
        object = @objects.data_for(ref)
        next if klass == TextPropertyValue and object[:text_value].blank?
        
        object[:id] = to_update_ids_by_ref[ref]
        object[:type] = object.delete(:class)
        Asset.new(object.keep(Asset::STORE_KEYS)).store! if klass == Asset
        
        bind_sets << bind_set
        bind_values += object.values_at(*local_symbols).map do |v|
          v = Base64.encode64(Marshal.dump(Marshal.load(Marshal.dump(v)))) if v.is_a?(Array) or v.is_a?(Hash)
          v
        end
        inserted_count += 1
      end
      
      begin
        @adapter.execute("INSERT INTO #{klass.storage_name} (#{column_names_list}) VALUES #{bind_sets.join(', ')}", *bind_values) unless bind_sets.empty?
        build_md5_report(klass)
      rescue Exception => e
        @errors << [nil, nil, e.message]
        error_count += 1
      end
    end
    
    if error_count > 0 then puts " --! #{error_count} errors encountered while inserting #{inserted_count}"
    elsif inserted_count > 0 then puts " --- inserted #{inserted_count}"
    end
  end
  
  def md5_table(klass)
    "#{klass.storage_name}_md5s"
  end
  
  def update_class(klass)
    return unless build_md5_report(klass)
    puts " - #{klass} records"
    to_update_ids_by_ref, valid_refs_seen = delete_and_update_from_db_md5_report(klass)
    insert_missing_refs(klass, to_update_ids_by_ref, valid_refs_seen)
  end
end
