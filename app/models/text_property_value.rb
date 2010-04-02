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
    marked_value = value.gsub(/[^\n\w\.\/\- !@%()'";:,?®™]/) { " >>> #{$1} <<< " }
    raise "invalid characters: #{marked_value}" if marked_value.size > value.size 
    {:text_value => value}
  end
  
  def comparison_key # TODO: spec
    [text_value]
  end
  
  def to_s(range_sep = nil) # TODO: spec
    text_value
  end
end
