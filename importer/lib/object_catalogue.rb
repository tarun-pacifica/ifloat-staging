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
    
    @objects_by_class_pk_md5 = {}
    @objects_by_row_md5 = {}
    Dir[@dir / "*"].each do |path|
      klass, pk_md5, val_md5, *row_md5s = File.basename(path).split("_")
      add_object(klass, pk_md5, val_md5, row_md5s)
    end
  end
  
  # TODO: make this atomic
  def add(csv_catalogue, objects, *row_md5s)
    objects.map do |object|
      klass = object[:class]
      pk_md5 = primary_key_md5(klass, object)
      
      existing = @objects_by_class_pk_md5[[klass, pk_md5]]
      if existing.nil?
        object = add_object(klass, pk_md5, value_md5(klass, object), row_md5s)
        Marshal.dump(object, File.open(@dir / object.flatten.join("_"), "w"))
        next
      end
      
      e_klass, e_pk_md5, e_val_md5, e_row_md5s = existing
      e_rows = e_row_md5s.map { |row_md5| csv_catalogue.row_info(row_md5).values_at(:name, :index).join(":") }
      "duplicate of #{e_klass} from #{e_rows.join(', ')} (based on #{PRIMARY_KEYS[klass].join(' / ')})"
    end.compact
  end
  
  def add_object(klass, pk_md5, val_md5, row_md5s)
    object = [klass, pk_md5, val_md5, row_md5s]
    @objects_by_class_pk_md5[[klass, pk_md5]] = object
    row_md5s.each { |row_md5| (@objects_by_row_md5[row_md5] ||= []) << object }
    object
  end
  
  def attribute_md5(object, attributes)
    values = attributes.map do |attribute|
      value = object[attribute]
      value = "%.#{NumericPropertyValue.MAX_DP}f" % value if attribute == :min_value or attribute == :max_value
      
      case value
      when Array, Hash then Base64.encode64(Marshal.dump(value))
      when FalseClass, TrueClass then value ? 1 : 0
      when Integer, String then value
      else raise "#{klass} #{object.inspect} contains unknown type for #{attribute}: #{value.class} #{value.inspect}"
      end
    end
    
    Digest::MD5.hexdigest(values.join("::"))
  end
  
  def delete_obsolete(row_md5s)
    obsolete_row_md5s = (@objects_by_row_md5.keys - row_md5s)
    obsolete_objects = @objects_by_row_md5.values_at(*obsolete_row_md5s)
    obsolete_objects.map { |o| @dir / o[0] }.delete_and_log("obsolete objects")
    obsolete_objects.each { |o| @objects_by_class_pk_md5.delete(o[0, 2]) }
    build_catalogue unless obsolete_objects.empty?
  end
  
  def missing_auto_row_md5s(auto_row_md5s, product_row_md5s)
    missing_auto_row_md5s = []
    seen_row_md5s = []
    
    auto_row_md5s.each do |md5|
      objects = @objects_by_row_md5[md5]
      if objects.nil? then missing_auto_row_md5s << md5
      else seen_row_md5s += objects.map { |o| objects[3] }
      end
    end
    
    [missing_auto_row_md5s, product_row_md5s - seen_row_md5s]
  end
  
  def missing_row_md5s(row_md5s)
    row_md5s - @objects_by_row_md5.keys
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
