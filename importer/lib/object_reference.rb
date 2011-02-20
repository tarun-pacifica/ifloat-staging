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
  
  def self.coerce_to_md5(values)
    coerced = values.map do |value|
      case value
      when Array, Hash                   then Base64.encode64(Marshal.dump(value))
      when BigDecimal                    then "%.#{NumericPropertyValue.MAX_DP}f" % value
      when FalseClass, TrueClass         then value ? 1 : 0
      when Integer, String               then value
      when ObjectLookup, ObjectReference then value.pk_md5
      when nil                           then ""
      else raise "unable to coerce #{value.class} #{value.inspect}"
      end
    end
    
    Digest::MD5.hexdigest(coerced.join("::"))
  end
  
  def self.from_object(object, dir)
    klass = object[:class]
    pk_md5 = coerce_to_md5(object.values_at(*PRIMARY_KEYS[klass]))
    val_md5 = value_md5(klass, object)
    name = [klass, pk_md5, val_md5].join("_")
    new(dir / name, klass, pk_md5, val_md5)
  end
  
  def self.from_path(path)
    klass, pk_md5, val_md5 = File.basename(path).split("_")
    new(path, Kernel.const_get(klass), pk_md5, val_md5)
  end
  
  @@loose_md5s_by_pk_values = {}
  def self.loose(klass, pk_values)
    md5 = (@@loose_md5s_by_pk_values[pk_values] ||= coerce_to_md5(pk_values))
    ObjectLookup.new(klass, md5)
  end
  
  def self.value_md5(klass, object)
    rel_names_by_child_key = Hash[klass.relationships.map { |name, rel| [rel.child_key.first.name, name.to_sym] }]
    property_names = klass.properties.map do |property|
      name = property.name
      rel_names_by_child_key[name] || name
    end
    
    attributes = (property_names - PRIMARY_KEYS[klass] - [:id, :type]).sort_by { |sym| sym.to_s }
    coerce_to_md5(object.values_at(*attributes))
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
    simplified = object.map do |attribute, value|
      value = ObjectLookup.new(value.klass, value.pk_md5) if value.is_a?(ObjectReference)
      [attribute, value]
    end
    File.open(@path, "w") { |f| Marshal.dump(Hash[simplified], f) }
  end
end
