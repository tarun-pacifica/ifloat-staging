REPO_DIRS = Hash[["assets", "csvs"].map { |d| [d, Merb.root / ".." / "ifloat_#{d}"] }]

ASSET_CSV_PATH       = "/tmp/ifloat_assets.csv"
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
  puts "\nErrors occured whilst #{whilst}"
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
csv_paths = Dir[REPO_DIRS["csvs"] / "**" / "*.csv"] + [ASSET_CSV_PATH]
# TODO: track PH, TS and product CSVs for later multi-row objects
csv_md5s = csv_paths.map { |path| MarshaledCSV.marshal_updated(path, CSV_INDEX_DIR) }.to_set

obsolete_csv_index_paths = Dir[CSV_INDEX_DIR / "*"].reject { |path| csv_md5s.include?(File.basename(path)) }
obsolete_csv_index_paths.delete_and_log("obsolete CSV indexes")

# TODO: use CSV tracking here to establish PH, TS and product rows
row_md5s = Dir[CSV_INDEX_DIR / "*" / "*"].map { |path| File.basename(path) }.to_set
row_md5s.delete("info")
puts " > managing #{row_md5s.size} rows in total"


# TODO: replace with...
# indexes/single_row_object_names/row_md5 => marshal(object_paths: Product/pkmd5_valmd5, TextPropertyValue/pkmd5_valmd5, ...)
# indexes/multi_row_object_names/UUID => marshal(object_paths)

# 1. TS row 2 -> single_row_object_names/rowmd5.tmp = marshal("TitleStrategy/pkmd5_valmd5")
#             -> objects/TitleStrategy/pkmd5_valmd5 = marshal(object)
#             -> mv(rowmd5.tmp -> rowmd5)
# 2. Product row 54 -> indexes/single_row_objects/rowmd5.tmp = marshal("Product/p_v", "TextPropertyValue/p_v")
#             -> objects/.... = marshaled(objects)
#             -> mv(rowmd5.tmp -> rowmd5)
# NB: rows to generate = (row_md5s - <non-TMP row_md5s in row_objects>)
# NB: multi_rows to generate = (title + property)_rows * (products)_rows
# 3. combo(TS row 2, Product row 54) -> multi_row_object_names/row1md5_row2md5.tmp = marshal("TextPropertyValue/p_v")
#             -> objects/... = marshaled(objects) : MOST OFTEN NONE - make the above file empty rather than marshal([])
#             -> mv(row1md5_row2md5.tmp -> row1md5_row2md5)

# p DataMapper::Model.sorted_descendants(PropertyDefinition => [PropertyHierarchy, TitleStrategy])
