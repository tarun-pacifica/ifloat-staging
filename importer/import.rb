$KCODE = "UTF-8" unless RUBY_VERSION =~ /^1\.9\./

REPO_DIRS = Hash[["assets", "csvs"].map { |d| [d, Merb.root / ".." / "ifloat_#{d}"] }]

ASSET_CSV_PATH       = REPO_DIRS["csvs"] / "assets.csv"
ASSET_VARIANT_DIR    = "/tmp" / "ifloat_asset_variants_new"
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
mail_fail("generating row objects") if generator.write_errors(ERROR_CSV_PATH)
objects.summarize

puts "Generating any missing auto objects..."
generator = AutoObjectGenerator.new(csvs, objects)
generator.generate
mail_fail("generating auto objects") if generator.write_errors(ERROR_CSV_PATH)
objects.summarize

puts "Running global integrity checks..."
objects.verifier.verify
mail_fail("verifying global integrity") if objects.verifier.write_errors(ERROR_CSV_PATH)

puts "Updating database..."
updater = DatabaseUpdater.new(classes, csvs, objects)
updater.update
mail_fail("updating database") if updater.write_errors(ERROR_CSV_PATH)
