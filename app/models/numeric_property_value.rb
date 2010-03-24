# = Summary
#
# See the PropertyValue superclass.
#
class NumericPropertyValue < PropertyValue
  FRACTIONAL_UNITS = %w(ft in).to_set
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
  
  # TODO: spec to reflect params and default unit behaviour (fractional support etc...)
  def self.format(min_value, max_value, range_separator = "...", unit = nil, params = {})
    params[:unit] = unit
    [min_value, max_value].uniq.map { |v| format_value(v, params) }.join(range_separator) +
    (unit.nil? ? "" : " #{unit}")
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
  
  # TODO: spec
  def comparison_key
    key = [min_value]
    key << max_value unless min_value == max_value
    key << unit unless unit.nil?
    key
  end
  
  # TODO: spec
  def to_s(range_separator = "...")
    self.class.format(min_value, max_value, range_separator, unit)
  end
  
  
  protected
  
  def self.format_value(value, params = {})
    return value.to_s if value.is_a?(Integer)
    
    f = value.to_f
    i = value.to_i
    return i.to_s if i == f
    
    # TODO: spec
    if FRACTIONAL_UNITS.include?(params[:unit])
      denominator = 2
      remainder = f - i
      while(denominator < 128) do
        numerator = (remainder * denominator)
        n = numerator.to_i
        return "#{i} #{n}/#{denominator}" if n == numerator
        denominator *= 2
      end
    end
    
    f.to_s
  end
  
  def self.parse_atom(atom)
    raise "number is blank" if atom == ""
    raise "non-numeric characters in #{atom.inspect}" if atom =~ /[^0-9\-\+ \.e]/
    value = BigDecimal.new(atom).round(MAX_DP)
    raise "number #{value} is outside the range #{VALUE_RANGE}" unless VALUE_RANGE.include?(value)    
    value
  end
end
