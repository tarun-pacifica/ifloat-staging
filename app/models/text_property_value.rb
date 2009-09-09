# = Summary
#
# See the PropertyValue superclass.
#
class TextPropertyValue < PropertyValue
  property :language_code, String, :format => /^[A-Z]{3}$/
  property :text_value, Text, :lazy => false
  
  validates_present :language_code, :text_value
  
  # TODO: spec
  def self.parse_or_error(value)
    raise "invalid characters in #{value.inspect}" unless value =~ /\A[\n\w\.\/\- !@%()'";:,?®™]+\z/
    {:text_value => value}
  end
  
  # TODO: document and test
  def self.translated_values(product_ids, language_code)
    return {} if product_ids.empty?
    
    tpvs = all(:product_id => product_ids, :language_code => language_code)
    
    property_ids = tpvs.map { |tpv| tpv.property_definition_id }.uniq
    PropertyDefinition.all(:id => property_ids).map
    
    values_by_property_by_product_id = {}
    tpvs.each do |tpv|
      values_by_property = (values_by_property_by_product_id[tpv.product_id] ||= {})
      (values_by_property[tpv.definition] ||= []) << tpv.text_value
    end
    values_by_property_by_product_id
  end
  
  def self.text? # TODO: spec (in this class and parent only)
    true
  end
  
  def to_s # TODO: spec
    text_value
  end
  
  def value
    text_value
  end
end
