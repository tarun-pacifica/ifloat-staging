class FasterCSV::Row
  def has_nil_values?
    any? { |header, value| value.nil? }
  end
  
  def has_values_in(set)
    any? { |header, value| set.includes?(value) }
  end
  
  def repeated_non_nil_values
    map { |header, value| value }.compact.repeated
  end
end
