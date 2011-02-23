$KCODE = "UTF-8" unless RUBY_VERSION =~ /^1\.9\./

REPO_DIRS = Hash[["assets", "csvs"].map { |d| [d, Merb.root / ".." / "ifloat_#{d}"] }]

ASSET_CSV_PATH       = REPO_DIRS["csvs"] / "assets.csv"
ASSET_VARIANT_DIR    = "/tmp/ifloat_asset_variants_new"
ASSET_WATERMARK_PATH = Merb.root / "public" / "images" / "common" / "watermark.png"
ERROR_CSV_PATH       = "/tmp/ifloat_errors.csv"

THIS_DIR             = Merb.root / "importer"
INDEXES_DIR          = THIS_DIR / "indexes"
CSV_INDEX_DIR        = INDEXES_DIR / "csvs"
OBJECT_INDEX_DIR     = INDEXES_DIR / "objects"

[ASSET_VARIANT_DIR, CSV_INDEX_DIR, OBJECT_INDEX_DIR].each { |dir| FileUtils.mkpath(dir) }

%w(lib parsers).each { |dir| Dir[THIS_DIR / dir / "*.rb"].each { |path| load path } }


def mail_fail(whilst)
  puts " ! errors occured whilst #{whilst}"
  if Merb.environment == "development"
    system "mate", ERROR_CSV_PATH
  else
    mail_info = {:whilst => whilst, :repo_summary => GitRepo.summarize(REPO_DIRS), :attach => ERROR_CSV_PATH}
    Mailer.deliver(:import_failure, mail_info)
  end
  exit 1
end


puts "Scanning asset repository for updates..."
assets = ImportableAssets.new(REPO_DIRS["assets"], ASSET_CSV_PATH, ASSET_VARIANT_DIR, ASSET_WATERMARK_PATH)
unless assets.update
  assets.write_errors(ERROR_CSV_PATH)
  mail_fail("compiling assets")
end


puts "Scanning CSV repository for updates..."
csvs = CSVCatalogue.new(CSV_INDEX_DIR)
Dir[REPO_DIRS["csvs"] / "**" / "*.csv"].each { |path| csvs.add(path) }
mail_fail("compiling CSVs") if csvs.write_errors(ERROR_CSV_PATH)
csvs.delete_obsolete
csvs.summarize


puts "Updating objects..."
objects = ObjectCatalogue.new(OBJECT_INDEX_DIR)
objects.delete_obsolete(csvs.row_md5s)
row_md5s_to_parse = objects.missing_row_md5s(csvs.row_md5s)

all_errors = []
extra_dependency_rules = {Asset => [Product], PropertyDefinition => [AssociatedWord, PropertyHierarchy, TitleStrategy]}
DataMapper::Model.sorted_descendants(extra_dependency_rules).each do |model|
  name = model.storage_name
  csvs.infos_for_name(/^#{name}/).each do |csv_info|
    csv_row_md5s_to_parse = (csv_info[:row_md5s] & row_md5s_to_parse) # not using sets to avoid extra sort operation
    next if csv_row_md5s_to_parse.empty?
    
    parser = Kernel.const_get("#{model}Parser").new(csv_info, objects)
    all_errors += parser.header_errors
    if all_errors.size > 0
      require "pp"
      pp all_errors
      exit
    end
    next unless parser.header_errors.empty?
    
    parsed_count, error_count = 0, 0
    csv_row_md5s_to_parse.each do |row_md5|
      row_objects, errors = parser.parse_row(csvs.row(csv_info[:md5], row_md5))
      if row_objects.empty? and errors.empty? then errors << [nil, "no objects parsed from this row"]
      else errors += objects.add(csvs, row_objects, row_md5).map { |e| [nil, e] }
      end
      all_errors += errors.map { |col, e| [csv_info[:name], csvs.row_info(row_md5)[:index], col, e] }
      
      parsed_count += row_objects.size
      error_count += errors.size
    end
    
    puts " - parsed #{parsed_count} objects from #{csv_row_md5s_to_parse.size}/#{csv_info[:row_md5s].size} rows of #{csv_info[:name]}" if parsed_count > 0
    puts " ! #{error_count} errors reported from #{csv_info[:name]}" if error_count > 0
    
    if error_count > 0
      require "pp"
      pp all_errors
      exit
    end
    
    objects.commit(csv_info[:name].tr("/", "_"))
  end
end

# ph_row_md5s = csvs.row_md5s_for_name(/^property_hierarchies/)
# ts_row_md5s = csvs.row_md5s_for_name(/^title_strategies/)
# product_row_md5s = csvs.row_md5s_for_name(/^products\//)
# p [ph_row_md5s.size, ts_row_md5s.size, product_row_md5s.size]
# 
# missing_ph_row_md5s, missing_product_row_md5s = objects.missing_auto_row_md5s(ph_row_md5s, product_row_md5s)
# p [missing_ph_row_md5s.size, missing_product_row_md5s.size]
# missing_ts_row_md5s, missing_product_row_md5s = objects.missing_auto_row_md5s(ts_row_md5s, product_row_md5s)
# p [missing_ts_row_md5s.size, missing_product_row_md5s.size]
