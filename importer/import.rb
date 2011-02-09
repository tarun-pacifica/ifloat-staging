REPO_DIRS = Hash[ ["assets", "csvs"].map { |d| [d, Merb.root / ".." / "ifloat_#{d}"] } ]

THIS_DIR         = Merb.root / "importer"
INDEXES_DIR      = THIS_DIR / "indexes"
CSV_INDEX_DIR    = INDEXES_DIR / "csvs"
OBJECT_INDEX_DIR = INDEXES_DIR / "objects"

[CSV_INDEX_DIR, OBJECT_INDEX_DIR].each { |dir| FileUtils.mkpath(dir) }

Dir[THIS_DIR / "lib" / "*.rb"].each { |path| load path }


# TODO: generate asset records

puts "Scanning CSV repository for updates..."
csv_paths = Dir[REPO_DIRS["csvs"] / "**" / "*.csv"]
csv_md5s = csv_paths.map { |path| MarshaledCSV.marshal_updated(path, CSV_INDEX_DIR) }.to_set

obsolete_csv_index_paths = Dir[CSV_INDEX_DIR / "*"].reject { |path| csv_md5s.include?(File.basename(path)) }
obsolete_csv_index_paths.delete_and_log("obsolete CSV indexes")

row_md5s = Dir[CSV_INDEX_DIR / "*" / "*"].map { |path| File.basename(path) }.to_set
row_md5s.delete("info")
puts " > managing #{row_md5s.size} rows in total"

all_parent_row_md5s, to_delete = [], []
Dir[OBJECT_INDEX_DIR / "*" / "*"].each do |path|
  pk_md5, value_md5, *parent_row_md5s = File.basename(path).split("_")
  if parent_row_md5s.all? { |md5| row_md5s.include?(md5) } then all_parent_row_md5s += parent_row_md5s
  else to_delete << path
  end
end
to_delete.delete_and_log("obsolete objects")

row_md5s_to_generate = (row_md5s - all_parent_row_md5s.to_set)
puts "(Re-)generating objects from #{row_md5s_to_generate.size} rows..."

p DataMapper::Model.sorted_descendants(PropertyDefinition => [PropertyHierarchy, TitleStrategy])
