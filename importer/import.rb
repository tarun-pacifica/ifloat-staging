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

Dir[THIS_DIR / "lib" / "*.rb"].each { |path| load path }


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
csvs.delete_obsolete
csvs.summarize

puts "Updating objects..."
objects = ObjectCatalogue.new(OBJECT_INDEX_DIR)
objects.delete_obsolete(csvs.row_md5s)

row_md5s_to_parse = objects.missing_row_md5s(csvs.row_md5s)
puts " - #{row_md5s_to_parse.size} rows to parse"

ph_row_md5s = csvs.row_md5s_for_name(/^property_hierarchies/)
ts_row_md5s = csvs.row_md5s_for_name(/^title_strategies/)
product_row_md5s = csvs.row_md5s_for_name(/^products\//)
p [ph_row_md5s.size, ts_row_md5s.size, product_row_md5s.size]

missing_ph_row_md5s, missing_product_row_md5s = objects.missing_auto_row_md5s(ph_row_md5s, product_row_md5s)
p [missing_ph_row_md5s.size, missing_product_row_md5s.size]
missing_ts_row_md5s, missing_product_row_md5s = objects.missing_auto_row_md5s(ts_row_md5s, product_row_md5s)
p [missing_ts_row_md5s.size, missing_product_row_md5s.size]

# sorted_models = DataMapper::Model.sorted_descendants(PropertyDefinition => [PropertyHierarchy, TitleStrategy])
# sorted_tables = sorted_models.map { |m| m.storage_name }
