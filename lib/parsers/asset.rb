class AssetParser < AbstractParser
  HEADERS = %w(bucket company.reference name file_path checksum pixel_size file_path_small file_path_tiny)
  REQUIRED_VALUE_HEADERS = %w(bucket company.reference name file_path checksum).to_set
  
  
  private
  
  def generate_objects(parsed_fields)
    bucket, company, name, path, checksum, size, path_small, path_tiny = parsed_fields.values_at(*HEADERS)
    attributes = {:bucket => bucket, :company => company, :name => name, :file_path => path, :checksum => checksum, :pixel_size => size, :file_path_small => path_small, :file_path_tiny => path_tiny}
    [ImportObject.new(Asset, attributes)]
  end
  
  def parse_field(head, value, fields)
    return super unless head == "company.reference"
    @import_set.get!(Company, value)
  end
end
