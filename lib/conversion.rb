module Conversion
  EXCEPTIONS = %w(EU US-female US-male UK UK-child).to_set
  
  # conversion of v (unit 1) to V (unit 2): V = av + b
  # each mapping value is of the form [a, b]
  MAPPINGS = {
    ["#/in", "#/mm"]          => [1 / 25.4, 0],
    ["C", "F"]                => [1.8, 32],
    ["cm3", "in3"]            => [0.061024, 0],
    ["d", "h"]                => [24, 0],
    ["d", "min"]              => [1440, 0],
    ["d", "w"]                => [1.0 / 7, 0],
    ["daN", "kg"]             => [10 / 9.8067, 0],
    ["daN", "lb"]             => [10 * 2.2046 / 9.8067, 0],
    ["denier", "tex"]         => [1.0 / 9, 0],
    ["fl_oz", "fl_oz_us"]     => [0.96076, 0],
    ["fl_oz", "ml"]           => [28.413, 0],
    ["fl_oz_us", "gal_us"]    => [128, 0],
    ["fl_oz_us", "ml"]        => [29.574, 0],
    ["fl_oz_us", "pt_us"]     => [16, 0],
    ["fl_oz_us", "qt_us"]     => [32, 0],
    ["ft", "m"]               => [0.3048, 0],
    ["ft2", "m2"]             => [0.092903, 0],
    ["ft2/gal", "ft2/gal_us"] => [0.83267, 0],
    ["ft2/gal", "m2/li"]      => [0.020436, 0],
    ["ft2/gal_us", "m2/li"]   => [0.024542, 0],
    ["ft3", "gal"]            => [6.2288, 0],
    ["ft3", "gal_us"]         => [7.4805, 0],
    ["ft3", "li"]             => [28.317, 0],
    ["ft3/min", "li/min"]     => [28.317, 0],
    ["ft3", "m3"]             => [0.028317, 0],
    ["gal", "gal_us"]         => [1.2010, 0],
    ["gal/min", "gal_us/min"] => [1.2010, 0],
    ["gal", "li"]             => [4.5461, 0],
    ["gal/min", "li/min"]     => [4.5461, 0],
    ["gal", "m3"]             => [0.0045461, 0],
    ["gal_us", "li"]          => [3.7854, 0],
    ["gal_us/min", "li/min"]  => [3.7854, 0],
    ["gal_us", "m3"]          => [0.0037854, 0],
    ["gal_us", "pt_us"]       => [0.125, 0],
    ["gal_us", "qt_us"]       => [0.25, 0],
    ["h", "min"]              => [60, 0],
    ["h", "w"]                => [1.0 / 168, 0],
    ["HP", "kW"]              => [0.74570, 0],
    ["in", "mm"]              => [25.4, 0],
    ["in2", "mm2"]            => [645.16, 0],
    ["kg", "lb"]              => [2.2046, 0],
    ["kg/m", "lb/ft"]         => [0.67197, 0],
    ["kg/m2", "lb/ft2"]       => [0.20482, 0],
    ["kg/m3", "lb/ft3"]       => [0.062428, 0],
    ["kPa", "lb/in2"]         => [0.14504, 0],
    ["li", "m3"]              => [1.0 / 1000, 0],
    ["li", "ml"]              => [1.0 / 1000, 0]
    ["min", "w"]              => [1.0 / 10080, 0],
    ["mo", "y"]               => [1.0 / 12, 0]
  }
  
  def self.convert(value, from_unit, to_unit, sig_figs = determine_sig_figs(value))
    a, b = MAPPINGS[[from_unit, to_unit].sort]
    raise "no conversion available for #{from_unit.inspect} -> #{to_unit.inspect}" if a.nil?    
    converted_value = (from_unit < to_unit) ? (value * a + b) : ((value - b) / a)
    return 0 if converted_value == 0
    
    converted_integer = converted_value.to_i
    return converted_integer if converted_integer > 0 and Math.log10(converted_integer) >= sig_figs
    
    m = 10 ** (sig_figs - Math.log10(converted_value).ceil)
    (converted_value * m).round / m.to_f
  end
  
  def self.determine_sig_figs(value)
    value_string = value.to_f.to_s.delete(".")
    value_string =~ /^(0*)(.*?)(0*)$/
    [$2.size, 3].max
  end
  
  def self.javascript
    conversions = {}
    Conversion::MAPPINGS.each do |from_to, ab_values|
      conversions[from_to.join(">>")] = ab_values
    end
    
    <<-SCRIPT
    var util_conversions = #{conversions.to_json};

    function util_convert(value, from_unit, to_unit) {
    	var conversion_key = [from_unit, to_unit].sort().join(">>");
    	var ab_values = util_conversions[conversion_key];

    	if(ab_values == undefined) {
    		alert("no conversion available for" + from_unit + " -> " + to_unit);
    		return value;
    	}

     	var a = ab_values[0];
    	var b = ab_values[1];

    	return (from_unit < to_unit) ? (value * a + b) : ((value - b) / a);
    }
    SCRIPT
  end
  
  def self.required
    conversions = []
    
    PropertyType.all.each do |type|
      units = type.valid_units
      next if units.nil?
      
      units.compact!
      next if units.size < 2
      
      units.permutation(2).each do |pair|
        conversions << pair.sort
      end
    end
    
    conversions.uniq
  end
  
  def self.status
    r, m = required, MAPPINGS.keys
    {:missing => (r - m).sort, :unused => (m - r).sort}
  end
end
