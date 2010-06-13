class TitleStrategyParser < AbstractParser
  HEADERS = %w(Name Classes Title_1 Title_2 Title_3 Title_4 Title_5 Title_6)
  REQUIRED_VALUE_HEADERS = %w(Name)
  
  
  private
  
  def generate_objects(parsed_fields)
    attributes = {:name => parsed_fields["Name"], :class_names => parsed_fields["Classes"]}
    1.upto(6) { |i| attributes["title_#{i}".to_sym] = parsed_fields["Title_#{i}"] }
    [ImportObject.new(TitleStrategy, attributes)]
  end
  
  def parse_field(head, value, fields)
    case head
    when "Classes"
      value.to_s.split(",").map { |name| name.strip }
    when /^Title/
      value.to_s.split(",").map do |part|
        part.strip!
        @import_set.get!(PropertyDefinition, part) unless part == "-" or part == "product.reference"
        part
      end
    else
      super
    end
  end
end
