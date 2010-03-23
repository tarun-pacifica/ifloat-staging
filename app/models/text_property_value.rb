# coding: utf-8
#
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
  
  def comparison_key # TODO: spec
    [text_value]
  end
  
  def to_s(range_sep = nil) # TODO: spec
    text_value
  end
end
