class ObjectCatalogue
  def initialize(dir)
    @dir = dir
    
    @object_refs_by_class_pk_md5 = {}
    @object_refs_by_row_md5 = {}
    Dir[@dir / "*"].each { |path| add_object_ref(ObjectReference.from_path(path)) }
  end
  
  # TODO: make this atomic
  def add(csv_catalogue, objects, *row_md5s)
    objects.map do |object|
      object_row_md5s = (row_md5s + row_md5_chain_for_object(object)).flatten.uniq
      object_ref = ObjectReference.from_object(object, @dir, object_row_md5s)
      
      existing = @object_refs_by_class_pk_md5[object_ref.class_pk_md5]
      if existing.nil?
        object_ref.write(object)
        add_object_ref(object_ref)
        next
      end
      
      rows = existing.row_md5s.map { |row_md5| csv_catalogue.row_info(row_md5).values_at(:name, :index).join(":") }
      "duplicate of #{existing.klass} from #{rows.join(', ')}"
    end.compact
  end
  
  def add_object_ref(object_ref)
    @object_refs_by_class_pk_md5[object_ref.class_pk_md5] = object_ref
    object_ref.row_md5s.each { |row_md5| (@object_refs_by_row_md5[row_md5] ||= []) << object_ref }
  end
  
  def delete_obsolete(row_md5s)
    obsolete_row_md5s = (@object_refs_by_row_md5.keys - row_md5s)
    obsolete_object_refs = @object_refs_by_row_md5.values_at(*obsolete_row_md5s)
    obsolete_object_refs.map { |o| o.path }.delete_and_log("obsolete objects")
    obsolete_object_refs.each { |o| @object_refs_by_class_pk_md5.delete(o.class_pk_md5) }
    build_catalogue unless obsolete_object_refs.empty?
  end
  
  def has_object?(klass, pk_md5)
    @object_refs_by_class_pk_md5.has_key?([klass, pk_md5])
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
      else object_refs.each { |o| seen_row_md5s += o.row_md5s }
      end
    end
    
    [missing_auto_row_md5s, product_row_md5s - seen_row_md5s]
  end
  
  def missing_row_md5s(row_md5s)
    row_md5s - @object_refs_by_row_md5.keys
  end
  
  def row_md5_chain_for_object(object)
    case object
    when ObjectLookup    then row_md5_chain_for_object(lookup(object.klass, object.pk_md5))
    when ObjectReference then object.row_md5s + row_md5_chain_for_object(object.attributes)
    when Hash            then object.values.map { |v| row_md5_chain_for_object(v) }
    else []
    end
  end
end
