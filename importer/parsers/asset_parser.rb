class AssetParser < AbstractParser
  REQUIRED_HEADERS = %w(path bucket company_ref name checksum pixel_size path_wm path_small path_tiny)
  REQUIRED_VALUE_HEADERS = REQUIRED_HEADERS[0, 5]
  
  def generate_objects(parsed_fields)
    attributes = Hash[[:path, :bucket, :company, :name, :checksum, :pixel_size, :file_path, :file_path_small, :file_path_tiny].zip(parsed_fields.values_at(*REQUIRED_HEADERS))]
    attributes[:file_path] ||= attributes.delete(:path)
    [attributes.update(:class => Asset)]
  end
  
  def parse_field(head, value, fields)
    head == "company_ref" ? lookup!(Company, value) : value
  end
end
