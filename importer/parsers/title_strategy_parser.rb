class TitleStrategyParser < AbstractParser
  REQUIRED_HEADERS = REQUIRED_VALUE_HEADERS = %w(reference:class canonical description image)
  
  def generate_objects(parsed_fields)
    attributes = [:class_name, :canonical, :description, :image].zip(parsed_fields.values_at(*REQUIRED_HEADERS))
    [Hash[attributes].update(:class => TitleStrategy)]
  end
  
  def parse_field(head, value, fields)
    return value unless %w(canonical description image).include?(head)
    
    value.to_s.split(",").map do |part|
      part.strip!
      lookup!(PropertyDefinition, part) unless part == "-" or part == "product.reference"
      part
    end
  end
end
