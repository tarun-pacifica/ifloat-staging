# = Summary
#
# See the Filter superclass.
#
class NumericFilter < Filter
  property :unit_limits, Yaml, :lazy => false, :accessor => :protected
  property :chosen_min, BigDecimal, :precision => NumericPropertyValue::PRECISION, 
                                    :scale => NumericPropertyValue::MAX_DP,
                                    :accessor => :protected
  property :chosen_max, BigDecimal, :precision => NumericPropertyValue::PRECISION,
                                    :scale => NumericPropertyValue::MAX_DP,
                                    :accessor => :protected
  property :chosen_unit, String, :accessor => :protected
    
  validates_with_method :validate_limits_were_set
  def validate_limits_were_set
    limits || [false, "limits must be set with 'limits='"]
  end
  
  def choose(min, max, unit)
    return nil if limits.nil? or not limits.has_key?(unit)
    min_limit, max_limit = limits[unit]
    
    min = min_limit if min.nil?
    max = max_limit if max.nil?    
    min, max = [min, max].map { |m| [[m, min_limit].max, max_limit].min }.sort
      
    self.chosen_min = min
    self.chosen_max = max
    self.chosen_unit = unit
    
    self.fresh = (chosen == (limits[default_unit] + [default_unit]))
  end
  
  def choose!(min, max, unit)
    save unless choose(min, max, unit).nil?
  end
  
  def chosen
    [chosen_min, chosen_max, chosen_unit]
  end
  
  def date?
    property_definition.date?
  end
  
  def default_unit
    units.first
  end

  def limits
    return nil if unit_limits.nil?
    
    return @numeric_limits unless @numeric_limits.nil?
    
    @numeric_limits = {}
    unit_limits.each do |unit, min_max|
      @numeric_limits[unit] = min_max.map { |string_value| BigDecimal.new(string_value) }
    end
    @numeric_limits
  end
  
  def limits=(limits_by_unit)
    raise "expected a Hash of limits by unit but got #{limits_by_unit.inspect}" unless limits_by_unit.is_a?(Hash) and limits_by_unit.size > 0
    
    limits_by_unit.each do |unit, min_max|
      raise "expected a String / nil unit but got #{unit.inspect}" unless unit.nil? or unit.is_a?(String)
      raise "expected a limit Array but got #{min_max.inspect} for #{unit.inspect}" unless min_max.is_a?(Array) and min_max.size == 2 and min_max.all? { |m| m.is_a?(Numeric) }
    end
    
    @numeric_limits = limits_by_unit
    
    self.unit_limits = {}
    @numeric_limits.each do |unit, min_max|
      self.unit_limits[unit] = min_max.map { |decimal_value| decimal_value.to_s }
    end
    
    if limits_by_unit.has_key?(chosen_unit) then choose(chosen_min, chosen_max, chosen_unit)
    else choose(nil, nil, default_unit)
    end
  end
  
  def text?
    false
  end
  
  def units
    return [] if limits.nil?
    limits.keys.sort_by { |unit| unit.to_s }
  end
end