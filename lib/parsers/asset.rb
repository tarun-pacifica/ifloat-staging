class AssetParser < AbstractParser
  ESSENTIAL_HEADERS = ["bucket", "company.reference", "name", "file_path", "checksum"]
  
  
  private
  
  def generate_objects(parsed_fields)
    bucket, company, name, path, checksum = parsed_fields.values_at(*ESSENTIAL_HEADERS)
    attributes = {:bucket => bucket, :company => company, :name => name, :file_path => path, :checksum => checksum}
    [ImportObject.new(Asset, attributes)]
  end
  
  def parse_field(head, value, fields)
    return super unless head == "company.reference"
    @import_set.get!(Company, value)
  end
end
