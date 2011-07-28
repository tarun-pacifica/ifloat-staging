$KCODE = "UTF-8" unless RUBY_VERSION =~ /^1\.9\./

REPO_DIRS = Hash[["assets", "csvs"].map { |d| [d, Merb.root / ".." / "ifloat_#{d}"] }]

ASSET_CSV_PATH       = REPO_DIRS["csvs"] / "assets.csv"
ASSET_VARIANT_DIR    = Merb.root / "caches" / "asset_variants"
ASSET_WATERMARK_PATH = Merb.root / "public" / "images" / "common" / "watermark.png"
ERROR_CSV_PATH       = "/tmp" / "ifloat_importer_errors.csv"

THIS_DIR             = Merb.root / "importer"
INDEXES_DIR          = THIS_DIR / "indexes"
CSV_INDEX_DIR        = INDEXES_DIR / "csvs"
OBJECT_INDEX_DIR     = INDEXES_DIR / "objects"
VERIFIER_INDEX_DIR   = INDEXES_DIR / "verifier"

[ASSET_VARIANT_DIR, CSV_INDEX_DIR, OBJECT_INDEX_DIR, VERIFIER_INDEX_DIR].each { |dir| FileUtils.mkpath(dir) }

require THIS_DIR / "lib" / "error_writer"
%w(lib parsers).each { |dir| Dir[THIS_DIR / dir / "*.rb"].sort.each { |path| load path } }

IMPORTER_LOG_PATH = ENV["IMPORTER_LOG_PATH"]
unless IMPORTER_LOG_PATH.nil?
  $stdout = $stderr = File.open(IMPORTER_LOG_PATH, "w")
  $stdout.sync = $stderr.sync = true
end

def bomb(whilst)
  puts " ! errors occured whilst #{whilst}"
  system "mate", ERROR_CSV_PATH if Merb.environment == "development"
  exit 1
end

begin

puts "Scanning asset repository for updates..."
assets = ImportableAssets.new(REPO_DIRS["assets"], ASSET_CSV_PATH, ASSET_VARIANT_DIR, ASSET_WATERMARK_PATH)
unless assets.update
  assets.write_errors(ERROR_CSV_PATH)
  bomb("compiling assets")
end

puts "Scanning CSV repository for updates..."
csvs = CSVCatalogue.new(CSV_INDEX_DIR)
Dir[REPO_DIRS["csvs"] / "**" / "*.csv"].each { |path| csvs.add(path) }
bomb("compiling CSVs") if csvs.write_errors(ERROR_CSV_PATH)
csvs.delete_obsolete
csvs.summarize

puts "Recovering / updating object state..."
objects = ObjectCatalogue.new(csvs, OBJECT_INDEX_DIR, VERIFIER_INDEX_DIR)
objects.summarize
objects.add_queue("refs_by_product") do |ref, object|
  [object[:product], ref] if AutoObjectGenerator::VALUE_CLASSES.include?(object[:class])
end
objects.add_queue("refs_by_class") do |ref, object|
  [object[:class], ref]
end

puts "Generating any missing row objects..."
generator = RowObjectGenerator.new(csvs, objects)
extra_dependency_rules = {Asset => [Product], PropertyDefinition => [AssociatedWord, PropertyHierarchy, TitleStrategy]}
classes = DataMapper::Model.sorted_descendants(extra_dependency_rules)
classes.each { |klass| generator.generate_for(klass) }
bomb("generating row objects") if generator.write_errors(ERROR_CSV_PATH)
objects.summarize

puts "Generating any missing auto objects..."
generator = AutoObjectGenerator.new(csvs, objects)
generator.generate
bomb("generating auto objects") if generator.write_errors(ERROR_CSV_PATH)
objects.summarize

puts "Running global integrity checks..."
objects.verifier.verify
bomb("verifying global integrity") if objects.verifier.write_errors(ERROR_CSV_PATH)

puts "Updating database..."
updater = DatabaseUpdater.new(classes, csvs, objects)
updater.update
bomb("updating database") if updater.write_errors(ERROR_CSV_PATH)

puts "Recompiling indexes / expiring caches..."
Indexer.compile
PickedProduct.all.update!(:invalidated => true)
puts " > done"

rescue Exception => e
  File.open(ERROR_CSV_PATH, "w") { |f| f.puts "#{e.inspect}"; f.puts e.backtrace }
  
ensure
  File.delete(ENV["IMPORTER_CHECKPOINT_PATH"]) if ENV.has_key?("IMPORTER_CHECKPOINT_PATH")
  FileUtils.touch(ENV["IMPORTER_SUCCESS_PATH"]) if ENV.has_key?("IMPORTER_SUCCESS_PATH") and not File.exist?(ERROR_CSV_PATH)
  
end
