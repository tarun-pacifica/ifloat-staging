ObjectUniqueID = Class.new(String)

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
  
  def self._load(data)
    klass, pk_md5, value_md5, *row_md5s = data.split("_")
    ref = new(nil, row_md5s)
    ref.klass = klass
    ref.pk_md5 = pk_md5
    ref.value_md5 = value_md5
    ref
  end
  
  def self.coerce_to_md5(values)
    coerced = values.map do |value|
      case value
      when Array, Hash           then Base64.encode64(Marshal.dump(value))
      when BigDecimal            then "%.#{NumericPropertyValue::MAX_DP}f" % value
      when FalseClass, TrueClass then value ? 1 : 0
      when Integer, String       then value
      when ObjectReference       then value.pk_md5
      when nil                   then ""
      else raise "unable to coerce #{value.class} #{value.inspect}"
      end
    end
    
    Digest::MD5.hexdigest(coerced.join("::"))
  end
  
  def self.row_md5_chain(object)
    case object
    when Array           then object.map { |v| row_md5_chain(v) }
    when Hash            then object.values.map { |v| row_md5_chain(v) }
    when ObjectReference then object.row_md5s
    else []
    end
  end
  
  @@md5s_by_pk_values = {}
  def self.unique_id_for(klass, pk_values)
    md5 = (@@md5s_by_pk_values[pk_values] ||= coerce_to_md5(pk_values))
    ObjectUniqueID.new("#{klass}_#{md5}")
  end
  
  attr_accessor :klass, :pk_md5, :value_md5
  attr_reader :row_md5s
  attr_writer :catalogue
  
  def initialize(catalogue, row_md5s, object = nil)
    @catalogue = catalogue
    @row_md5s = row_md5s
    
    return if object.nil?
    
    @klass = object[:class]
    
    pk_values = object.values_at(*PRIMARY_KEYS[klass])
    @pk_md5 = (@@md5s_by_pk_values[pk_values] ||= ObjectReference.coerce_to_md5(pk_values))
    
    rel_names_by_child_key = Hash[klass.relationships.map { |name, rel| [rel.child_key.first.name, name.to_sym] }]
    property_names = klass.properties.map do |property|
      name = property.name
      rel_names_by_child_key[name] || name
    end
    keys = (property_names - PRIMARY_KEYS[klass] - [:id, :type]).sort_by { |sym| sym.to_s }
    @value_md5 = ObjectReference.coerce_to_md5(object.values_at(*keys))
    
    @row_md5s = (row_md5s + ObjectReference.row_md5_chain(object)).flatten.uniq
  end
  
  def _dump(depth)
    ([@klass, @pk_md5, @value_md5] + @row_md5s).join("_")
  end
  
  def[](key)
    attributes[key]
  end
  
  def attributes
    @catalogue.lookup_data(unique_id)
  end
  
  def unique_id
    @unique_id ||= ObjectUniqueID.new("#{@klass}_#{@pk_md5}")
  end
end
