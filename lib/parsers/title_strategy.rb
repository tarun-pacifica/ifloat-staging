class TitleStrategyParser < AbstractParser
  HEADERS = REQUIRED_VALUE_HEADERS = %w(reference:class canonical description image)
  
  
  private
  
  def generate_objects(parsed_fields)
    attributes = {
      :class_name  => parsed_fields["reference:class"],
      :canonical   => parsed_fields["canonical"],
      :description => parsed_fields["description"],
      :image       => parsed_fields["image"]
    }
    [ImportObject.new(TitleStrategy, attributes)]
  end
  
  def parse_field(head, value, fields)
    return super unless %w(canonical description image).include?(head)
    
    value.to_s.split(",").map do |part|
      part.strip!
      @import_set.get!(PropertyDefinition, part) unless part == "-" or part == "product.reference"
      part
    end
  end
end
