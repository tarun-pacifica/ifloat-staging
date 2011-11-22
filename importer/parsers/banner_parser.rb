class BannerParser < AbstractParser
  REQUIRED_HEADERS = %w(description location link_url image width height custom_html)
  REQUIRED_VALUE_HEADERS = %w(description location)
  
  def generate_objects(parsed_fields)
    attributes = [:description, :location, :link_url, :asset, :width, :height, :custom_html].zip(parsed_fields.values_at(*REQUIRED_HEADERS))
    [Hash[attributes].update(:class => Banner)]
  end
  
  def parse_field(head, value, fields)
    raise "invalid location: #{value.inspect}" if head == "location" and not Banner::LOCATIONS.include?(value)
    (head == "image" and not value.nil?) ? lookup!(Asset, "banners", lookup!(Company, "GBR-OC357582"), value) : value
  end
end
