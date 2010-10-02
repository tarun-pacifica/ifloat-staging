class AssociatedWordParser < AbstractParser
  HEADERS = %w(associated_words)
  
  
  private
  
  def generate_objects(parsed_fields)
    word = parsed_fields.delete(:word)
    parsed_fields.delete_if { |property, value| value.nil? }
    return [] if parsed_fields.empty?
    
    rules = {}
    parsed_fields.each do |property, value|
      rules[property.attributes[:name]] = value
    end
      
    [ImportObject.new(AssociatedWord, :word => word, :rules => rules)]
  end
  
  def parse_field(head, value, fields)
    value == "N/A" ? nil : TextPropertyValue.parse_or_error(value)[:text_value]
  end
  
  def parse_header(header)
    case header      
    when "associated_words" then :word
    when /^(.+?:.+?)$/      then @import_set.get!(PropertyDefinition, $1)
    else raise "unknown/invalid header: #{header}"
    end
  end
  
  def reject_blank_value?(head)
    true
  end
end
