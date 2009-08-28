class TitleStrategyParser < AbstractParser
  ESSENTIAL_HEADERS = ["Name", "Classes", "Title_1", "Title_2", "Title_3", "Title_4"]
  
  
  private
  
  def generate_objects(parsed_fields)
    attributes = {:name => parsed_fields["Name"], :class_names => parsed_fields["Classes"]}
    1.upto(4) { |i| attributes["title_#{i}".to_sym] = parsed_fields["Title_#{i}"] }
    [ImportObject.new(TitleStrategy, attributes)]
  end
  
  def parse_field(head, value, fields)
    case head
    when "Classes"
      value.to_s.split(",").map { |name| name.strip }
    when /^Title/
      value.to_s.split(",").map do |part|
        part.strip!
        @import_set.get!(PropertyDefinition, part) unless part == "-"
        part == "-" ? "SEP" : part
      end
    else
      super
    end
  end
  
  def reject_blank_value?(head)
    head == "Name"
  end
end
