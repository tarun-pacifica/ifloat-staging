class ObjectCatalogue
  MARSHALED_DIR           = "marshaled"
  ROW_CATALOGUE_FILE_NAME = "_row_catalogue"
  
  def initialize(dir)
    @row_catalogue_path = dir / ROW_CATALOGUE_FILE_NAME
    @marshaled_dir = dir / MARSHALED_DIR
    FileUtils.mkpath(@marshaled_dir)
    build_catalogue
  end
  
  def add(csv_catalogue, objects, *row_md5s)
    row_catalogue_size = @row_md5s_by_class_pk_md5.size
    
    errors = objects.map do |object|
      object_ref = ObjectReference.from_object(object, @marshaled_dir)
      
      existing = @object_refs_by_class_pk_md5[object_ref.class_pk_md5]
      if existing.nil?
        object_ref.write(object)
        add_object_ref(object_ref, (row_md5s + row_md5_chain_for_object(object)).flatten.uniq)
        next
      end
      
      e_row_md5s = (@row_md5s_by_class_pk_md5[existing.class_pk_md5] || [])
      rows = e_row_md5s.map { |row_md5| csv_catalogue.row_info(row_md5).values_at(:name, :index).join(":") }.join(", ")
      rows = "unknown csvs / rows" if rows.blank?
      "duplicate of #{existing.klass} from #{rows}"
    end.compact
    
    errors
  end
  
  def add_object_ref(object_ref, row_md5s = nil)
    @object_refs_by_class_pk_md5[object_ref.class_pk_md5] = object_ref
    
    @row_md5s_by_class_pk_md5[object_ref.class_pk_md5] = row_md5s unless row_md5s.nil?
    row_md5s ||= (@row_md5s_by_class_pk_md5[object_ref.class_pk_md5] || ["to_delete"])
    row_md5s.each { |row_md5| (@object_refs_by_row_md5[row_md5] ||= []) << object_ref }
  end
  
  def build_catalogue
    @object_refs_by_class_pk_md5 = {}
    @object_refs_by_row_md5 = {}
    @row_md5s_by_class_pk_md5 = (File.open(@row_catalogue_path) { |f| Marshal.load(f) } rescue {})
    
    Dir[@marshaled_dir / "*"].each { |path| add_object_ref(ObjectReference.from_path(path)) }
    @row_md5s_by_class_pk_md5.delete_if { |class_pk_md5, row_md5s| lookup(*class_pk_md5) != nil }
  end
  
  def commit
    File.open(@row_catalogue_path, "w") { |f| Marshal.dump(@row_md5s_by_class_pk_md5, f) }
  end
  
  def delete_obsolete(row_md5s)
    obsolete_row_md5s = (@object_refs_by_row_md5.keys - row_md5s)
    obsolete_object_refs = @object_refs_by_row_md5.values_at(*obsolete_row_md5s).flatten
    obsolete_object_refs.map { |o| o.path }.delete_and_log("obsolete objects")
    obsolete_object_refs.each { |o| @object_refs_by_class_pk_md5.delete(o.class_pk_md5) }
    build_catalogue unless obsolete_object_refs.empty?
  end
  
  def lookup(klass, pk_md5)
    @object_refs_by_class_pk_md5[[klass, pk_md5]]
  end
  
  def missing_auto_row_md5s(auto_row_md5s, product_row_md5s)
    missing_auto_row_md5s = []
    seen_row_md5s = []
    
    auto_row_md5s.each do |md5|
      object_refs = @object_refs_by_row_md5[md5]
      if object_refs.nil? then missing_auto_row_md5s << md5
      else object_refs.each { |o| seen_row_md5s += (@row_md5s_by_class_pk_md5[o.class_pk_md5] || []) }
      end
    end
    
    [missing_auto_row_md5s, product_row_md5s - seen_row_md5s]
  end
  
  def missing_row_md5s(row_md5s)
    row_md5s - @object_refs_by_row_md5.keys
  end
  
  def row_md5_chain_for_object(object)
    case object
    when Array           then object.map { |v| row_md5_chain_for_object(v) }
    when Hash            then object.values.map { |v| row_md5_chain_for_object(v) }
    when ObjectLookup    then row_md5_chain_for_object(lookup(object.klass, object.pk_md5))
    when ObjectReference
      (@row_md5s_by_class_pk_md5[object.class_pk_md5] || []) + row_md5_chain_for_object(object.attributes)
    else []
    end
  end
end
