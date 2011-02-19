ObjectLookup = Struct.new(:klass, :pk_md5)

class ObjectReference
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
  
  def self.attribute_md5(object, attributes)
    values = attributes.map do |attribute|
      value = object[attribute]
      value = "%.#{NumericPropertyValue.MAX_DP}f" % value if attribute == :min_value or attribute == :max_value
      coerce_for_md5(value) or raise "#{object.inspect} contains unknown type: #{value.class} #{value.inspect}"
    end
    
    Digest::MD5.hexdigest(values.join("::"))
  end
  
  def self.coerce_for_md5(value)
    case value
    when Array, Hash           then Base64.encode64(Marshal.dump(value))
    when FalseClass, TrueClass then value ? 1 : 0
    when Integer, String       then value
    when ObjectLookup          then value.pk_md5
    else nil
    end
  end
  
  def self.from_object(object, dir)
    klass = object[:class]
    pk_md5 = attribute_md5(object, PRIMARY_KEYS[klass])
    val_md5 = value_md5(klass, object)
    name = [klass, pk_md5, val_md5].join("_")
    new(dir / name, klass, pk_md5, val_md5)
  end
  
  def self.from_path(path)
    klass, pk_md5, val_md5 = File.basename(path).split("_")
    new(path, Kernel.const_get(klass), pk_md5, val_md5)
  end
  
  def self.loose(klass, pk_values)
    coerced = pk_values.map do |value|
      coerce_for_md5(value) or raise "#{pk_values.inspect} contain unknown type: #{value.class} #{value.inspect}"
    end
    ObjectLookup.new(klass, Digest::MD5.hexdigest(coerced.join("::")))
  end
  
  def self.value_md5(klass, object)
    rel_names_by_child_key = Hash[klass.relationships.map { |name, rel| [rel.child_key.first.name, name.to_sym] }]
    property_names = klass.properties.map do |property|
      name = property.name
      rel_names_by_child_key[name] || name
    end
    
    attributes = (property_names - PRIMARY_KEYS[klass] - [:id, :type]).sort_by { |sym| sym.to_s }
    attribute_md5(object, attributes)
  end
    
  attr_reader :path, :klass, :pk_md5, :val_md5, :attributes
  
  def initialize(path, klass, pk_md5, val_md5)
    @path = path
    @klass = klass
    @pk_md5 = pk_md5
    @val_md5 = val_md5
  end
  
  def[](key)
    @attributes[key]
  end
  
  def attributes
    @attributes ||= File.open(@path) { |f| Marshal.load(f) }
  end
  
  def class_pk_md5
    [@klass, @pk_md5]
  end
  
  def write(object)
    File.open(@path, "w") { |f| Marshal.dump(object, f) }
  end
end
