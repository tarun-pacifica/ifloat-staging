class ObjectRef < String
  PRIMARY_KEYS = {
    PropertyType            => [:name],
    PropertyDefinition      => [:name],
    Translation             => [:property_definition, :language_code],
    PropertyValueDefinition => [:property_type, :value],
    AssociatedWord          => [:word, :rules],
    PropertyHierarchy       => [:class_name, :sequence_number],
    TitleStrategy           => [:class_name],
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
  
  def self.coerce_to_md5(values)
    coerced = values.map do |value|
      case value
      when Array, Hash         then Base64.encode64(Marshal.dump(value))
      when BigDecimal          then "%.#{NumericPropertyValue::MAX_DP}f" % value
      when Class, Integer, nil then value.to_s
      when false               then "0"
      when ObjectRef, String   then value
      when true                then "1"
      else raise "unable to coerce #{value.class} #{value.inspect}"
      end
    end
    
    Digest::MD5.hexdigest(coerced.join("::"))
  end
  
  def self.from_object(object)
    klass = object[:class]
    
    pk_md5 = self.for(klass, object.values_at(*PRIMARY_KEYS[klass]))
    
    rel_names_by_child_key = Hash[klass.relationships.map { |name, rel| [rel.child_key.first.name, name.to_sym] }]
    property_names = klass.properties.map do |property|
      name = property.name
      rel_names_by_child_key[name] || name
    end
    keys = (property_names - PRIMARY_KEYS[klass] - [:id, :type]).sort_by { |sym| sym.to_s }
    value_md5 = coerce_to_md5(object.values_at(*keys))
    
    [new(pk_md5), value_md5]
  end
  
  @@md5_cache = {}
  def self.for(klass, pk_values)
    pk_values = ([klass] + pk_values)
    @@md5_cache[pk_values] ||= new(coerce_to_md5(pk_values))
  end
  
  def[](key)
    attributes[key]
  end
  
  def attributes
    ObjectCatalogue.default.data_for(self)
  end
  
  def inspect_friendly
    a = attributes
    klass = a[:class]
    values = a.values_at(*PRIMARY_KEYS[klass]).map { |v| v.is_a?(ObjectRef) ? v.inspect_friendly : v }
    "#{klass}[#{values.join(' / ')}]"
  end
end
