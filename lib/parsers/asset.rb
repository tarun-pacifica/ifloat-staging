class AssetParser < AbstractParser
  ESSENTIAL_HEADERS = ["bucket", "company.reference", "name", "todo_notes", "file_path", "checksum"]
  
  
  private
  
  def generate_objects(parsed_fields)
    bucket, company, name, notes, path, checksum = parsed_fields.values_at(*ESSENTIAL_HEADERS)
    attributes = {:bucket => bucket, :company => company, :name => name, :todo_notes => notes, :file_path => path, :checksum => checksum}
    [ImportObject.new(Asset, attributes)]
  end
  
  def parse_field(head, value, fields)
    return super unless head == "company.reference"
    @import_set.get!(Company, value)
  end
  
  def reject_blank_value?(head)
    head != "todo_notes"
  end
end
