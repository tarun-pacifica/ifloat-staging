# coding: utf-8
#
# = Summary
#
# See the PropertyValue superclass.
#
class TextPropertyValue < PropertyValue
  property :language_code, String, :format => /^[A-Z]{3}$/
  property :text_value, Text, :lazy => false
  
  validates_presence_of :language_code, :text_value
  
  def self.parse_or_error(value)
    marked_value = value.gsub(/[^\n\w\.\/\- !@%()'";:,?®™#]/) { |c| " >>> #{c} <<< " }
    raise "invalid characters: #{marked_value}" if marked_value.size > value.size 
    {:text_value => value}
  end
  
  def comparison_key
    [text_value]
  end
  
  def to_s(range_sep = nil)
    text_value
  end
end
