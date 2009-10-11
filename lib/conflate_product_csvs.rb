# merb -i -r lib/conflate_product_csvs.rb

COMPILED_CSV_PATH = "caches/all_products.csv"
COMPILED_PATH = "caches/all_products.marshal"
CSV_REPO = "../ifloat_csvs"

[COMPILED_CSV_PATH, COMPILED_PATH].each do |path|
  File.delete(path) if File.exist?(path)
end

properties_by_name = PropertyDefinition.all.hash_by { |property| property.name }

universal_columns = {}
universal_r = 0

puts "=== Conflating Product CSVS ==="
Dir[CSV_REPO / "products" / "*.csv"].each do |path|
  start = Time.now
  FasterCSV.foreach(path, :headers => :first_row, :return_headers => false) do |row|
    row.each do |header, value|
      universal_column = (universal_columns[header] ||= [])
      universal_column[universal_r] = value
    end
    universal_r += 1
  end
  puts "#{'%6.2f' % (Time.now - start)}s : #{File.basename(path)}"
end

start = Time.now
universal_columns.each do |column_name, values|
  values[universal_r - 1] ||= nil
end

sorted_column_names = universal_columns.keys.sort_by do |col_name|
  case col_name
  when "company.reference" then [0]
  when "product.review_stage" then [1]
  when "product.reference" then [2]
  when /^mapping\.(.+?)$/ then [3, $1]
  when /^raw:.*?(\d+)$/ then [7, $1.to_i]
  when /^(.+?:.+?):(.*?):(\d+)(:tolerance)?$/ then [4, (properties_by_name[$1].sequence_number rescue 0).to_i, $3.to_i, $2, ($4.nil? ? 0 : 1)]
  when /^relationship\.(.+?)$/ then [5, $1]
  when /^attachment.(.+?).(\d+)$/ then [6, $1, $2.to_i]
  else [8]
  end
end

universal_rows = universal_columns.values_at(*sorted_column_names).transpose
File.open(COMPILED_PATH, "w") { |f| Marshal.dump({:headers => sorted_column_names, :rows => universal_rows}, f) }
puts "#{'%6.2f' % (Time.now - start)}s : #{COMPILED_PATH}"

start = Time.now
FasterCSV.open(COMPILED_CSV_PATH, "w") do |csv|
  csv << sorted_column_names
  universal_rows.each { |row| csv << row }
end
puts "#{'%6.2f' % (Time.now - start)}s : #{COMPILED_CSV_PATH}"