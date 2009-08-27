# = Summary
#
# See the PropertyValue superclass.
#
class DatePropertyValue < NumericPropertyValue
  validates_absent :tolerance, :unit
  
  def self.date?
    true
  end
  
    
  protected
  
  def self.parse_atom(atom)
    return nil if atom == "?" or (atom.is_a?(Numeric) and atom.abs == INFINITY)
    raise "invalid format (expected YYYYMMDD) in #{atom.inspect}" unless atom.to_s =~ /^(\d{4})(\d\d)(\d\d)$/
    raise "invalid format (expected YYYY0000) in #{atom.inspect}" if $2.to_i.zero? and $3.to_i > 0
    atom.to_i
  end
  
  def coerce_db_value_to_native(db_value)
    db_value.to_i
  end
  
  def coerce_native_to_string(native_value) # TODO: remove - all formatters should be in javascript
    v = native_value.to_i
    [v / 10000, (v / 100) % 100, v % 100].delete_if { |v| v.zero? }.join("/")
  end
end
