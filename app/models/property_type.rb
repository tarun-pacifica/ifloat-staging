# = Summary
#
# At the top of the chain of the property classes is the PropertyType. These objects govern the storage semantics and the acceptable units of every related PropertyValue. There should be comparitively few of these and their core types correspond to the four PropertyValue types (see CORE_TYPES for a complete list of allowed values).
#
# === Sample Data
#
# core_type:: 'numeric'
# name:: 'weight'
# units:: ["kg", "lb"]
#
class PropertyType
  include DataMapper::Resource
  
  CORE_TYPES = {
    "currency"    => "NumericPropertyValue",
    "date"        => "DatePropertyValue",
    "numeric"     => "NumericPropertyValue",
    "text"        => "TextPropertyValue"
  }
  
  property :id, Serial
  property :core_type, String, :nullable => false
  property :name, String, :nullable => false, :format => /^[a-z_]{3,}$/, :unique => true
  property :units, Object, :size => 255
  
  has n, :definitions, :class_name => "PropertyDefinition"
  has n, :value_definitions, :class_name => "PropertyValueDefinition"
  
  validates_absent :units, :unless => :numeric?
  validates_with_method :units, :method => :validate_numeric_units, :if => :numeric?
  validates_within :core_type, :set => CORE_TYPES.keys
  
  # TODO: rearrange spec
  def self.value_class(core_type)
    Kernel.const_get(CORE_TYPES[core_type])
  end
  
  # TODO: rearrange spec
  def self.validate_unit(unit, name, core_type, valid_units)
    case core_type
    when "currency"
      unit =~ /^[A-Z]{3}$/ || [false, "should always be an ISO-4217 code for a #{name}[#{core_type}] property"]
    when "numeric"
      valid_units = [nil] if valid_units.blank?
      valid_units.include?(unit) || [false, "invalid for a #{name}[#{core_type}] property"]
    else
      unit.nil? || [false, "should always be nil for a #{name}[#{core_type}] property"]
    end
  end
  
  def validate_unit(unit)
    PropertyType.validate_unit(unit, name, core_type, units)
  end
  
  def value_class
    PropertyType.value_class(core_type)
  end
  
  
  private
  
  def numeric?
    core_type == "numeric"
  end
  
  def validate_numeric_units
    return true if units.blank?
    
    error = [false, "should be an array of unique, valid units (or nil / [])"]
    
    return error unless units.is_a?(Array)
    return error unless units.repeated.empty?
    return error unless units.all? { |unit| unit.to_s =~ /^[\w\/%]+$/ }
    
    missing_conversions = []
    units.permutation(2).each do |pair|
      from, to = pair
      begin
        Conversion.convert(1, from, to) if from < to
      rescue
        missing_conversions << "#{from} -> #{to}"
      end
    end
    return [false, "should only specify units which already have conversions defined (missing: #{missing_conversions.join(', ')})"] unless missing_conversions.empty?
    
    true
  end
end
