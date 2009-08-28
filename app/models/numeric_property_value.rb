# = Summary
#
# See the PropertyValue superclass.
#
class NumericPropertyValue < PropertyValue
  INFINITY = (1.0/0)
  MAX_DP = 6
  PRECISION = 15
  VALUE_RANGE = BigDecimal.new("-999999999.999999")..BigDecimal.new("999999999.999999")
  
  property :unit, String
  property :min_value, BigDecimal, :precision => PRECISION, :scale => MAX_DP, :accessor => :protected
  property :max_value, BigDecimal, :precision => PRECISION, :scale => MAX_DP, :accessor => :protected
  property :tolerance, Float
  
  # TODO: ensure no specs address this / stub for it
  # validates_with_block :unit do
  #   if property_type.nil? then [false, "unable to verify unit (no property type)"]
  #   else property_type.validate_unit(unit)
  #   end
  # end
  
  validates_with_method :validate_value_was_set
  def validate_value_was_set
    (min_value or max_value) || [false, "value must be set with 'value='"]
  end
  
  # TODO: update spec
  def self.convert(from_attributes, to_unit)
    min_value, max_value = parse_or_error(from_attributes[:value])
    tolerance = from_attributes[:tolerance]
    unit = from_attributes[:unit]
    
    max_sig_figs = [min_value, max_value].compact.map { |v| Conversion.determine_sig_figs(v) }.max
    converted_min = min_value.nil? ? -INFINITY : Conversion.convert(min_value.to_f, unit, to_unit, max_sig_figs)
    converted_max = max_value.nil? ? INFINITY : Conversion.convert(max_value.to_f, unit, to_unit, max_sig_figs)
    attributes = {:unit => to_unit, :value => converted_min..converted_max}
    
    attributes[:tolerance] = Conversion.convert(tolerance, unit, to_unit) unless tolerance.nil?
    attributes
  end
  
  def self.date?
    false
  end
  
  def self.limits_by_unit_by_property_id(product_ids)
    query =<<-EOS
      SELECT property_definition_id, unit,
        MIN(min_value) AS min_min, MAX(min_value) AS max_min,
        MIN(max_value) AS min_max, MAX(max_value) AS max_max
      FROM property_values
      WHERE type IN ('NumericPropertyValue', 'DatePropertyValue')
        AND product_id IN ?
      GROUP BY property_definition_id, unit
    EOS
    
    units_by_property_id = {}
    repository.adapter.query(query, product_ids).each do |record|
      min = [record.min_min, record.min_max].compact.min
      max = [record.max_min, record.max_max].compact.max

      limits_by_unit = (units_by_property_id[record.property_definition_id] ||= {})
      limits_by_unit[record.unit] = [min, max]
    end
    units_by_property_id
  end
    
  # TODO: spec
  def self.parse_or_error(data)
    min, max = 
      case data
      when nil
        raise "number is nil"
      when Array
        data
      when Range
        [data.first, data.last]
      when String
        if data =~ /^(.+?)(\.{2,})(.+?)$/
          raise "badly formatted range in #{data.inspect}" unless $2 == "..."
          [$1, $3]
        else [data, data]
        end
      else
        [data, data]
      end
    
    min, max = [min, max].map { |m| parse_atom(m) }
    
    raise "cannot have infinity for both the lower and upper bounds" if min.nil? and max.nil?
    raise "the lower bound must not be greater than the upper bound" unless min.nil? or max.nil? or min <= max
    
    [min, max]
  end
  
  def range?
    min_value != max_value
  end
  
  def to_s # TODO: spec for Num and Date
    v = value
    values = (range? ? [v.first, v.last] : [v])
    values.map { |v| v.abs == INFINITY ? "?" : coerce_native_to_string(v) }.join("...")
  end
  
  def value
    return coerce_db_value_to_native(min_value) unless range?
    min = (min_value.nil? ? -INFINITY : coerce_db_value_to_native(min_value))
    max = (max_value.nil? ? INFINITY : coerce_db_value_to_native(max_value))
    min..max
  end
  
  def value=(data)
    self.min_value, self.min_value = self.class.parse_or_error(data)
  end
  
  
  protected
  
  def self.parse_atom(atom)
    return nil if atom == "?" or (atom.is_a?(Numeric) and atom.abs == INFINITY)
    
    value = atom
    unless value.is_a?(BigDecimal)
      atom = atom.to_s
      raise "number is blank" if atom == ""
      raise "non-numeric characters in #{atom.inspect}" if atom =~ /[^0-9\-\+ \.e]/
      value = BigDecimal.new(atom).round(MAX_DP)
    end
    raise "number #{value} is outside the range #{VALUE_RANGE}" unless VALUE_RANGE.include?(value)    
    value
  end
  
  def coerce_native_to_string(native_value)
    native_value.to_s
  end
  
  def coerce_db_value_to_native(db_value)
    db_value
  end
end
