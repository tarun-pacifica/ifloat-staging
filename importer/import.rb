REPO_DIRS = Hash[ ["assets", "csvs"].map { |d| [d, Merb.root / ".." / "ifloat_#{d}"] } ]

THIS_DIR         = Merb.root / "importer"
INDEXES_DIR      = THIS_DIR / "indexes"
CSV_INDEX_DIR    = INDEXES_DIR / "csvs"
OBJECT_INDEX_DIR = INDEXES_DIR / "objects"

[CSV_INDEX_DIR, OBJECT_INDEX_DIR].each { |dir| FileUtils.mkpath(dir) }

# TODO: generate asset records

puts "Scanning CSV repository for updated CSVs..."

csv_md5s = []
Dir[REPO_DIRS["csvs"] / "**" / "*.csv"].each do |path|
  csv_md5 = Digest::MD5.file(path).hexdigest(path)
  csv_md5s << csv_md5
  name = (File.dirname(path) =~ /products$/ ? "products/" : "") + File.basename(path)
  index_dir = CSV_INDEX_DIR / csv_md5
  info_path = index_dir / "info"
  
  if File.directory?(index_dir)
    next if File.exist?(info_path)
    puts " - #{name} PARTIAL UPDATE DETECTED (erasing and starting again)"
    FileUtils.rmtree(index_dir)
  end
  
  FileUtils.mkpath(index_dir)
  
  row_md5s = []
  FasterCSV.foreach(path, :headers => :first_row, :return_headers => true, :encoding => "UTF-8") do |row|
    row = Marshal.dump(row.map { |header, value| value })
    row_md5 = Digest::MD5.hexdigest(row)
    row_md5s << row_md5
    File.open(index_dir / row_md5, "w") { |f| f.write(row) }
  end
  
  Marshal.dump({:name => name, :row_md5s => row_md5s}, File.open(info_path, "w"))
  puts " - #{name} (read #{row_md5s.size} rows)"
end
csv_md5s = csv_md5s.to_set


to_delete = Dir[CSV_INDEX_DIR / "*"].reject { |path| csv_md5s.include?(File.basename(path)) }
if to_delete.size > 0
  FileUtils.rmtree(to_delete)
  puts "Deleted #{to_delete.size} obsolete CSV indexes"
end


row_md5s = Dir[CSV_INDEX_DIR / "*" / "*"].map { |path| File.basename(path) }.to_set
row_md5s.delete("info")
puts "Managing #{row_md5s.size} rows in total"


all_parent_row_md5s, to_delete = [], []
Dir[OBJECT_INDEX_DIR / "*"].each do |path|
  pk_md5, value_md5, *parent_row_md5s = File.basename(path).split("_")
  if parent_row_md5s.all? { |md5| row_md5s.include?(md5) } then all_parent_row_md5s += parent_row_md5s
  else to_delete << path
  end
end
if to_delete.size > 0
  FileUtils.rmtree(to_delete)
  puts "Deleted #{to_delete.size} obsolete objects"
end

row_md5s_to_generate = (row_md5s - all_parent_row_md5s.to_set)
puts "(Re-)generating objects from #{row_md5s_to_generate.size} rows..."
