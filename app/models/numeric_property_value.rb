# = Summary
#
# See the PropertyValue superclass.
#
class NumericPropertyValue < PropertyValue
  MAX_DP = 6
  PRECISION = 15
  VALUE_RANGE = BigDecimal.new("-999999999.999999")..BigDecimal.new("999999999.999999")
  
  property :unit, String
  property :min_value, BigDecimal, :precision => PRECISION, :scale => MAX_DP
  property :max_value, BigDecimal, :precision => PRECISION, :scale => MAX_DP
  property :tolerance, Float
  
  validates_present :min_value, :max_value
  
  def self.convert(from_attributes, to_unit)
    min, max = from_attributes.values_at(:min_value, :max_value)
    tolerance = from_attributes[:tolerance]
    unit = from_attributes[:unit]
    
    attributes = {:unit => to_unit}
    attributes[:tolerance] = Conversion.convert(tolerance, unit, to_unit) unless tolerance.nil?
    
    max_sig_figs = [min, max].map { |v| Conversion.determine_sig_figs(v) }.max
    attributes[:min_value] = Conversion.convert(min.to_f, unit, to_unit, max_sig_figs)
    attributes[:max_value] = Conversion.convert(max.to_f, unit, to_unit, max_sig_figs)
    
    attributes
  end
  
  def self.date?
    false
  end
  
  def self.format(min_value, max_value, range_separator = "...")
    [min_value, max_value].uniq.map { |v| format_value(v) }.join(range_separator)
  end
  
  def self.format_value(value)
    return value.to_s if value.is_a?(Integer)
    f = value.to_f
    i = value.to_i
    f == i ? i.to_s : f.to_s
  end
    
  def self.parse_or_error(value)
    raise "expected numeric value/range as string" unless value.is_a?(String)
    
    min, max = value, value
    if value =~ /^(.+?)(\.{2,})(.+?)$/
      raise "badly formatted range in #{value.inspect}" unless $2 == "..."
      min, max = $1, $3
    end
    
    min, max = [min, max].map { |m| parse_atom(m) }    
    raise "the lower bound must not be greater than the upper bound" if min > max
    {:min_value => min, :max_value => max}
  end
  
  def range?
    min_value != max_value
  end
  
  def value
    return coerce_db_value_to_native(min_value) unless range?
    coerce_db_value_to_native(min_value)..coerce_db_value_to_native(max_value)
  end
  
  
  protected
  
  def self.parse_atom(atom)
    raise "number is blank" if atom == ""
    raise "non-numeric characters in #{atom.inspect}" if atom =~ /[^0-9\-\+ \.e]/
    value = BigDecimal.new(atom).round(MAX_DP)
    raise "number #{value} is outside the range #{VALUE_RANGE}" unless VALUE_RANGE.include?(value)    
    value
  end
  
  def coerce_db_value_to_native(db_value)
    db_value
  end
end
