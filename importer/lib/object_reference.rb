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
  
  @@md5s_by_values = {}
  def self.coerce_to_md5(values, cache = false)
    if cache
      cached = @@md5s_by_values[values]
      return cached unless cached.nil?
    end
    
    coerced = values.map do |value|
      case value
      when Array, Hash           then Base64.encode64(Marshal.dump(value))
      when BigDecimal            then "%.#{NumericPropertyValue.MAX_DP}f" % value
      when FalseClass, TrueClass then value ? 1 : 0
      when Integer, String       then value
      when ObjectLookup          then value.pk_md5
      when NilClass              then ""
      else raise "unable to coerce #{value.class} #{value.inspect}"
      end
    end
    
    md5 = Digest::MD5.hexdigest(coerced.join("::"))
    @@md5s_by_values[values] = md5 if cache
    md5
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
  
  def self.loose(klass, pk_values)
    ObjectLookup.new(klass, coerce_to_md5(pk_values, true))
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
    File.open(@path, "w") { |f| Marshal.dump(object, f) }
  end
end
