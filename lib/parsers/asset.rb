class AssetParser < AbstractParser
  ESSENTIAL_HEADERS = ["bucket", "company.reference", "name", "file_path", "checksum", "pixel_size", "file_path_small", "file_path_tiny"]
  
  
  private
  
  def generate_objects(parsed_fields)
    bucket, company, name, path, checksum, size, path_small, path_tiny = parsed_fields.values_at(*ESSENTIAL_HEADERS)
    attributes = {:bucket => bucket, :company => company, :name => name, :file_path => path, :checksum => checksum, :pixel_size => size, :file_path_small => path_small, :file_path_tiny => path_tiny}
    [ImportObject.new(Asset, attributes)]
  end
  
  def parse_field(head, value, fields)
    return super unless head == "company.reference"
    @import_set.get!(Company, value)
  end
  
  def reject_blank_value?(head)
    not %w(pixel_size file_path_small file_path_tiny).include?(head)
  end
end
