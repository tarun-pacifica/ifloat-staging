class AssociatedWordParser < AbstractParser
  REQUIRED_HEADERS = REQUIRED_VALUE_HEADERS = %w(associated_words)
  
  def generate_objects(parsed_fields)
    word = parsed_fields.delete("associated_words")
    parsed_fields.delete_if { |property, value| value.blank? }
    parsed_fields.empty? ? [] : [{:class => AssociatedWord, :word => word, :rules => parsed_fields}]
  end
  
  def parse_field(head, value, fields)
    TextPropertyValue.parse_or_error(value)[:text_value] unless value.blank?
  end
  
  def parse_header(header)
    case header
    when "associated_words" then "associated_words"
    when /^(.+?:.+?)$/      then lookup!(PropertyDefinition, $1); $1
    else raise "unknown/invalid header: #{header}"
    end
  end
end
