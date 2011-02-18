class TitleStrategyParser < AbstractParser
  REQUIRED_HEADERS = %w(Name Classes Canonical Description Image)
  REQUIRED_VALUE_HEADERS = %w(Name)
  
  
  private
  
  def generate_objects(parsed_fields)
    attributes = [:name, :class_names, :canonical, :description, :image].zip(parsed_fields.values_at(*REQUIRED_HEADERS))
    [Hash[attributes].update(:class => TitleStrategy)]
  end
  
  def parse_field(head, value, fields)
    case head
    when "Classes"
      value.to_s.split(",").map { |name| name.strip }
    when "Canonical", "Description", "Image"
      value.to_s.split(",").map do |part|
        part.strip!
        lookup(PropertyDefinition, part) unless part == "-" or part == "product.reference"
        part
      end
    else
      value
    end
  end
end
