class TitleStrategyParser < AbstractParser
  HEADERS = %w(Name Classes Canonical Description Image)
  REQUIRED_VALUE_HEADERS = %w(Name)
  
  
  private
  
  def generate_objects(parsed_fields)
    attributes = {
      :name        => parsed_fields["Name"],
      :class_names => parsed_fields["Classes"],
      :canonical   => parsed_fields["Canonical"],
      :description => parsed_fields["Description"],
      :image       => parsed_fields["Image"]
    }
    [ImportObject.new(TitleStrategy, attributes)]
  end
  
  def parse_field(head, value, fields)
    case head
    when "Classes"
      value.to_s.split(",").map { |name| name.strip }
    when "Canonical", "Description", "Image"
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
