class AssetParser < AbstractParser
  ESSENTIAL_HEADERS = ["bucket", "company.reference", "name", "file_path", "checksum", "file_path_small", "file_path_tiny"]
  
  
  private
  
  def generate_objects(parsed_fields)
    bucket, company, name, path, checksum, path_small, path_tiny = parsed_fields.values_at(*ESSENTIAL_HEADERS)
    attributes = {:bucket => bucket, :company => company, :name => name, :file_path => path, :checksum => checksum, :file_path_small => path_small, :file_path_tiny => path_tiny}
    [ImportObject.new(Asset, attributes)]
  end
  
  def parse_field(head, value, fields)
    return super unless head == "company.reference"
    @import_set.get!(Company, value)
  end
  
  def reject_blank_value?(head)
    head != "file_path_small" and head != "file_path_tiny"
  end
end
