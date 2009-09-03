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
  
  # TODO: review as likely defunct
  def self.limits_by_unit_by_property_id(product_ids, property_ids)
    return {} if product_ids.empty? or property_ids.empty?
    
    query =<<-EOS
      SELECT property_definition_id, unit,
        MIN(min_value) AS min_min, MAX(min_value) AS max_min,
        MIN(max_value) AS min_max, MAX(max_value) AS max_max
      FROM property_values
      WHERE type IN ('NumericPropertyValue', 'DatePropertyValue')
        AND product_id IN ?
        AND property_definition_id IN ?
      GROUP BY property_definition_id, unit
    EOS
    
    units_by_property_id = {}
    repository.adapter.query(query, product_ids, property_ids).each do |record|
      min = [record.min_min, record.min_max].compact.min
      max = [record.max_min, record.max_max].compact.max

      limits_by_unit = (units_by_property_id[record.property_definition_id] ||= {})
      limits_by_unit[record.unit] = [min, max]
    end
    units_by_property_id
  end
  
  validates_with_method :validate_limits_were_set
  def validate_limits_were_set
    limits || [false, "limits must be set with 'limits='"]
  end
  
  def choose!(min, max, unit)
    return if limits.nil? or not limits.has_key?(unit)
    min_limit, max_limit = limits[unit]
    
    min =
      if suppress?(:min) then nil
      elsif min.nil? then min_limit
      else [[min, min_limit].compact.max, max_limit].compact.min
      end
      
    max =
      if suppress?(:max) then nil
      elsif max.nil? then max_limit
      else [[max, min_limit].compact.max, max_limit].compact.min
      end
      
    min, max = max, min if min.is_a?(Numeric) and max.is_a?(Numeric) and min > max
      
    self.chosen_min = min
    self.chosen_max = max
    self.chosen_unit = unit
    
    self.fresh = (chosen == (limits[default_unit] + [default_unit]))
    
    save
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
  
  def excluded_product_query_chunk(language_code)
    return [] if limits.nil?
    
    query =<<-EOS
      property_definition_id = ? AND
      unit #{chosen_unit.nil? ? "IS" : "="} ? AND
      (IFNULL(? > max_value, FALSE) OR IFNULL(? < min_value, FALSE))
    EOS
    
    [query, property_definition_id, chosen_unit, chosen_min, chosen_max]
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
      raise "expected a limit Array but got #{min_max.inspect} for #{unit.inspect}" unless min_max.is_a?(Array) and min_max.size == 2
      raise "expected no more than one nil limit but got two for #{unit.inspect}" if min_max.compact.empty?
      min_max.each { |m| raise "expected a Numeric / nil value but got #{m.inspect} for #{unit.inspect}" unless m.nil? or m.is_a?(Numeric) }
    end
    
    @numeric_limits = limits_by_unit
    
    self.unit_limits = {}
    @numeric_limits.each do |unit, min_max|
      self.unit_limits[unit] = min_max.map { |decimal_value| decimal_value.to_s }
    end
    
    raise "detected nils for minima and maxima across the entire set of limits" if suppress?(:min) and suppress?(:max)
    if limits.has_key?(chosen_unit) then choose!(chosen_min, chosen_max, chosen_unit)
    else choose!(nil, nil, default_unit)
    end
  end
  
  def suppress?(set)
    return true if limits.nil?
    limits.any? { |unit, limits| (set == :min ? limits.first : limits.last).nil? }
  end
  
  def text?
    false
  end
  
  def units
    return [] if limits.nil?
    limits.keys.sort_by { |unit| unit.to_s }
  end
end