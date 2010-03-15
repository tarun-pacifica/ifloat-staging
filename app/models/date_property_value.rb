# = Summary
#
# See the PropertyValue superclass.
#
class DatePropertyValue < NumericPropertyValue
  FORMATS = {
    :compact => ["%Y", "%Y-%m", "%Y-%m-%d"],
    :verbose => ["%Y", "%B %Y", "%B %d, %Y"]
  }
  
  validates_absent :tolerance, :unit
  
  def self.date?
    true
  end
  
  # TODO: spec verbose examples
  def self.format_value(value, params = {})
    v = value.to_i
    ymd = [v / 10000, (v / 100) % 100, v % 100].select { |n| n > 0 }    
    format = FORMATS[params[:verbose] ? :verbose : :compact][ymd.size - 1]
    Date.new(*ymd).strftime(format)
  end
  
    
  protected
  
  def self.parse_atom(atom)
    raise "invalid format (expected YYYYMMDD) in #{atom.inspect}" unless atom.to_s =~ /^(\d{4})(\d\d)(\d\d)$/
    raise "invalid format (expected YYYY0000) in #{atom.inspect}" if $2.to_i.zero? and $3.to_i > 0
    atom.to_i
  end
  
  def coerce_db_value_to_native(db_value)
    db_value.to_i
  end
end
