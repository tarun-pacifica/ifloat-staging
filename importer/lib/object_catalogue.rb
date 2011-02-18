class ObjectCatalogue
  # TODO: this may need a better home
  PRIMARY_KEYS = {
    PropertyType            => [:name],
    PropertyDefinition      => [:name],
    Translation             => [:property_definition, :language_code],
    PropertyValueDefinition => [:property_type, :value],
    AssociatedWord          => [:word, :rules],
    PropertyHierarchy       => [:class_name, :sequence_number],
    TitleStrategy           => [:name],
    UnitOfMeasure           => [:class_name],
    Company                 => [:reference],
    Facility                => [:company, :name],
    Asset                   => [:bucket, :company, :name],
    Brand                   => [:company, :name],
    Product                 => [:company, :reference],
    Attachment              => [:product, :role, :sequence_number],
    ProductMapping          => [:company, :product, :reference],
    ProductRelationship     => [:company, :product, :property_definition, :name, :value],
    DatePropertyValue       => [:product, :definition, :sequence_number],
    NumericPropertyValue    => [:product, :definition, :sequence_number, :unit],
    TextPropertyValue       => [:product, :definition, :sequence_number, :language_code]
  }
  
  def initialize(dir)
    @dir = dir
    
    @object_refs_by_class_pk_md5 = {}
    @object_refs_by_row_md5 = {}
    Dir[@dir / "*"].each { |path| add_object_ref(ObjectReference.from_path(path)) }
  end
  
  # TODO: make this atomic
  def add(csv_catalogue, objects, *row_md5s)
    objects.map do |object|
      klass = object[:class]
      pk_md5 = primary_key_md5(klass, object)
      
      existing = @object_refs_by_class_pk_md5[[klass, pk_md5]]
      if existing.nil?
        object_ref = ObjectReference.from_memory(@dir, klass, pk_md5, value_md5(klass, object), row_md5s)
        object_ref.write(object)
        add_object_ref(object_ref)
        next
      end
      
      rows = existing.row_md5s.map { |row_md5| csv_catalogue.row_info(row_md5).values_at(:name, :index).join(":") }
      "duplicate of #{existing.klass} from #{rows.join(', ')} (based on #{PRIMARY_KEYS[klass].join(' / ')})"
    end.compact
  end
  
  def add_object_ref(object_ref)
    @object_refs_by_class_pk_md5[object_ref.class_pk_md5] = object_ref
    object_ref.row_md5s.each { |row_md5| (@object_refs_by_row_md5[row_md5] ||= []) << object_ref }
  end
  
  def attribute_md5(object, attributes)
    values = attributes.map do |attribute|
      value = object[attribute]
      value = "%.#{NumericPropertyValue.MAX_DP}f" % value if attribute == :min_value or attribute == :max_value
      
      case value
      when Array, Hash then Base64.encode64(Marshal.dump(value))
      when FalseClass, TrueClass then value ? 1 : 0
      when Integer, String then value
      when ObjectReference then value.pk_md5
      else raise "#{klass} #{object.inspect} contains unknown type for #{attribute}: #{value.class} #{value.inspect}"
      end
    end
    
    Digest::MD5.hexdigest(values.join("::"))
  end
  
  def delete_obsolete(row_md5s)
    obsolete_row_md5s = (@object_refs_by_row_md5.keys - row_md5s)
    obsolete_object_refs = @object_refs_by_row_md5.values_at(*obsolete_row_md5s)
    obsolete_object_refs.map { |o| o.path }.delete_and_log("obsolete objects")
    obsolete_object_refs.each { |o| @object_refs_by_class_pk_md5.delete(o.class_pk_md5) }
    build_catalogue unless obsolete_object_refs.empty?
  end
  
  def lookup(klass, *pk_values)
    pk_md5 = Digest::MD5.hexdigest(pk_values.join("::"))
    object_ref = @object_refs_by_class_pk_md5[[klass, pk_md5]]
    raise "invalid/unknown #{klass}: #{friendly_pk(pk_value)}" if object_ref.nil? # TODO: fix error
    object_ref
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
  
  def primary_key_md5(klass, object)
    attribute_md5(object, PRIMARY_KEYS[klass])
  end
  
  def value_md5(klass, object)
    property_names = klass.properties.map { |property| property.name }
    attributes = (property_names - PRIMARY_KEYS[klass] - [:id, :type]).sort_by { |sym| sym.to_s }
    attribute_md5(object, attributes)
  end
end
