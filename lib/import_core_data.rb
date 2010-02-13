# merb -i -r lib/import_core_data.rb

require "lib/parsers/abstract"

ASSET_CSV_PATH = "/tmp/assets.csv"
ASSET_ERRORS_PATH = "/tmp/basic_asset_errors.csv"
ASSET_REPO = "../ifloat_assets"
ASSET_VARIANT_DIR = "/tmp/ifloat_asset_variants"
FileUtils.mkpath(ASSET_VARIANT_DIR)

CSV_REPO = "../ifloat_csvs"

CLASSES = [PropertyType, PropertyDefinition, PropertyValueDefinition, TitleStrategy, Company, Facility, Asset, Product]

class ImportObject
  attr_accessor :primary_key, :resource
  attr_reader :klass, :attributes, :path, :row
  
  def initialize(klass, attributes)
    @klass = klass
    @attributes = attributes
  end
  
  def resource_id
    @resource.nil? ? attributes[:id] : @resource.id
  end
  
  def set_source(path, row)
    @path = path
    @row = row
  end
end

class ImportSet
  PRIMARY_KEYS = {
    PropertyType            => [:name],
    PropertyDefinition      => [:name],
    Translation             => [:property_definition, :language_code],
    PropertyValueDefinition => [:property_type, :value],
    TitleStrategy           => [:name],
    Company                 => [:reference],
    Facility                => [:company, :name],
    Asset                   => [:bucket, :company, :name],
    Product                 => [:company, :reference],
    Attachment              => [:product, :role, :sequence_number],
    ProductMapping          => [:company, :product, :reference],
    ProductRelationship     => [:company, :product, :property_definition, :name, :value],
    DatePropertyValue       => [:product, :definition, :sequence_number],
    NumericPropertyValue    => [:product, :definition, :sequence_number, :unit],
    TextPropertyValue       => [:product, :definition, :sequence_number, :language_code]
  }
  
  def initialize
    @errors = []
    @objects = []
    @objects_by_pk_by_class = {}
  end
  
  def add(object)
    @objects << object
    klass = object.klass
    
    pk = object.attributes.values_at(*PRIMARY_KEYS[klass])
    error(klass, object.path, object.row, nil, "unable to establish primary key") if pk.nil?
    return if pk.nil? or pk.any? { |v| v.nil? }
    object.primary_key = pk
    
    objects_by_pk = (@objects_by_pk_by_class[klass] ||= {})
    existing = objects_by_pk[pk]
    
    if existing.nil? then objects_by_pk[pk] = object
    else error(klass, object.path, object.row, nil, "duplicate of #{existing.path} row #{existing.row}: #{friendly_pk(pk)}")
    end
  end
  
  def error(klass, path, row, column, message)
    @errors << [klass, path, row, column, message]
  end
  
  def get(klass, *pk_value)
    objects = (@objects_by_pk_by_class[klass] || {})
    pk_value.empty? ? objects : objects[pk_value]
  end
  
  def get!(klass, *pk_value)
    object = get(klass, *pk_value)
    raise "invalid/unknown #{klass}: #{friendly_pk(pk_value)}" if object.nil?
    object
  end
  
  def import    
    @objects_by_pk_by_class = nil
    def add; raise "add cannot be called once import has been"; end
    
    classes = []
    objects_by_class = {}
    
    @objects.each do |object|
      klass = object.klass
      classes << klass unless classes.include?(klass)
      (objects_by_class[klass] ||= []) << object
    end
    
    class_stats = []
    
    DataMapper.repository(:default) do
      @adapter = DataMapper.repository(:default).adapter
      transaction = DataMapper::Transaction.new(@adapter)
      transaction.begin
      @adapter.push_transaction(transaction)
      
      classes.each do |klass|
        stopwatch(klass) { class_stats << [klass, import_class(klass, objects_by_class.delete(klass))] }
        break unless @errors.empty?
      end

      @adapter.pop_transaction
      if @errors.empty? then transaction.commit
      else transaction.rollback
      end
    end
    
    class_stats
  end
  
  def verify_integrity
    pias_by_product = stopwatch("derived primary image list") { primary_image_attachments }
    
    # stopwatch("ensured all products have a primary image") do
    #   (@objects.select { |object| object.klass == Product } - pias_by_product.keys).each do |product|
    #     error(Product, product.path, product.row, nil, "no image specified")
    #   end
    # end
    
    stopwatch("ensured all primary images are 400x400 in size") do
      assets = pias_by_product.values.map { |attachment| attachment.attributes[:asset] }.uniq
      assets_by_path = assets.hash_by { |asset| asset.attributes[:file_path] }
      
      `gm identify #{assets_by_path.keys.map { |k| k.inspect }.join(" ")}`.lines.each do |line|
        unless line =~ /^(.+?\.(jpg|png)).*?(\d+x\d+)/
          error(Asset, nil, nil, nil, "unable to read GM.identify report line: #{line.inspect}")
          next
        end
        next if $3 == "400x400"
        
        asset = assets_by_path[$1]
        if asset.nil?
          error(Asset, nil, nil, nil, "unable to associate GM.identify report line: #{line.inspect}")
        else
          error(Asset, asset.path, asset.row, nil, "not 400x400 (#{$3}): #{$1.inspect}")
        end
      end
      
      error(Asset, nil, nil, nil, "GM.identify command failed") unless $?.success?
    end
    exit 1
    
    stopwatch("ensured no orphaned PickedProducts") do
      PickedProduct.all_primary_keys.each do |company_ref, product_ref|
        company = get(Company, company_ref)
        if company.nil?
          error(Company, nil, nil, nil, "unable to delete company with user-referenced product: #{company_ref} / #{product_ref}")
        else
          error(Product, nil, nil, nil, "unable to delete user-referenced product: #{company_ref} / #{product_ref}") if get(Product, company, product_ref).nil?
        end
      end
    end
  end
  
  def write_errors(path)
    return false if @errors.empty?
    FasterCSV.open(path, "w") do |error_report|
      error_report << ["class", "path", "row", "column", "error"]
      @errors.each { |fields| error_report << fields }
    end
    true
  end


  private
  
  def friendly_pk(pk_value)
    friendly_pk_unpack(pk_value).flatten.map { |v| v.inspect }.join(" / ")
  end
  
  def friendly_pk_unpack(pk_value)
    pk_value.map { |v| v.is_a?(ImportObject) ? friendly_pk_unpack(v.primary_key) : v }
  end
  
  def import_class(klass, objects)
    relationships = {}
    klass.relationships.each do |attribute, relationship|
      relationships[attribute.to_sym] = relationship.child_key.first.name
    end
    
    pk_fields, value_fields = pk_and_value_fields(klass)
    existing_catalogue = value_md5s_and_ids_by_pk_md5(klass, pk_fields, value_fields)
    
    to_save = []
    to_save_pk_md5s = []
    to_skip_pk_md5s = []
    
    objects.each do |object|
      attributes = {}
      object.attributes.each do |key, value|
        key = relationships[key] if relationships.has_key?(key)
        attributes[key] = (value.is_a?(ImportObject) ? value.resource_id : value)
      end
      
      pk = attributes.values_at(*pk_fields)
      pk_md5 = Digest::MD5.hexdigest(pk.join("::"))
      existing_value_md5, existing_id = existing_catalogue[pk_md5]
      if existing_id.nil?
        object.resource = klass.new(attributes)
        to_save << object
        to_save_pk_md5s << pk_md5
        next
      end
      
      values = value_fields.map do |attribute|
        value = attributes[attribute]
        value = "%.6f" % value if attribute == :min_value or attribute == :max_value
        
        case value
        when Array then Base64.encode64(Marshal.dump(value))
        when FalseClass, TrueClass then value ? 1 : 0
        else value
        end
      end
      
      value_md5 = (values.empty? ? nil : Digest::MD5.hexdigest(values.join("::")))
            
      if value_md5 == existing_value_md5
        object.attributes[:id] = existing_id
        to_skip_pk_md5s << pk_md5
        next
      end
      
      object.resource = klass.get(existing_id)
      object.resource.attributes = attributes
      to_save << object
      to_save_pk_md5s << pk_md5
    end
    
    to_destroy_pk_md5s = (existing_catalogue.keys - to_save_pk_md5s) - to_skip_pk_md5s
    to_destroy_ids = existing_catalogue.values_at(*to_destroy_pk_md5s).map { |value_md5, id| id }
    to_destroy_ids.each_slice(1000) { |ids| klass.all(:id => ids).destroy! }
    stats = {:created => 0, :updated => 0, :destroyed => to_destroy_ids.size, :skipped => to_skip_pk_md5s.size}
    
    to_save.each do |object|
      stats[object.resource.new? ? :created : :updated] += 1
      next if object.resource.save
      object.resource.errors.full_messages.each { |message| error(klass, object.path, object.row, nil, message) }
    end
            
    stats
  end
  
  def pk_and_value_fields(klass)
    properties = klass.properties
    relationships = klass.relationships
    
    pk_fields = PRIMARY_KEYS[klass].map do |attribute|
      properties.named?(attribute) ? attribute : relationships[attribute].child_key.first.name
    end
    
    value_fields = (properties.map { |property| property.name } - pk_fields - [:id, :type]).sort_by { |sym| sym.to_s }
    value_fields -= [:chain_id, :chain_sequence_number] if klass == Asset
    
    [pk_fields, value_fields]
  end
  
  def primary_image_attachments
    attachments_by_product = {}
    (@objects_by_pk_by_class[Attachment] || []).each do |pk, attachment|
      product, role, sequence_number = pk
      next unless role == "image"
      a = attachments_by_product[product]
      attachments_by_product[product] = attachment if a.nil? or a.attributes[:sequence_number] > sequence_number
    end
    attachments_by_product
  end
  
  def value_md5s_and_ids_by_pk_md5(klass, pk_fields, value_fields)
    pk_fields, value_fields = [pk_fields, value_fields].map do |fields|
      fields.map { |f| "IFNULL(#{f}, '')" }.join(",'::',")
    end
    
    query = "SELECT id, MD5(CONCAT(#{pk_fields})) AS pk_md5"
    query += (value_fields.empty? ? ", NULL AS value_md5" : ", MD5(CONCAT(#{value_fields})) AS value_md5")
    query += " FROM #{klass.storage_name}"
    query += " WHERE type = '#{klass}'" if klass.properties.named?(:type)
  
    results = {}
    @adapter.select(query).each do |record|
      results[record.pk_md5] = [record.value_md5, record.id]
    end
    results
  end
end

def build_asset_csv
  return nil if File.exist?(ASSET_CSV_PATH) and File.mtime(ASSET_CSV_PATH) > repo_mtime(ASSET_REPO)
  
  assets = []
  errors = []
  
  paths_by_names_by_company_refs = {}
  
  Dir[ASSET_REPO / "**" / "*"].each do |path|
    next unless File.file?(path)
    
    raise "unable to extract relative path from #{path.inspect}" unless path =~ /^#{ASSET_REPO}\/(.+)/
    relative_path = $1
    path_parts = relative_path.split("/")
    
    unless (3..4).include?(path_parts.size)
      errors << [relative_path, "not in a bucket/company or bucket/company/class directory"]
      next
    end
    
    errors << [relative_path, "empty file"] if File.size(path).zero?
    
    bucket = path_parts.shift
    errors << [relative_path, "unknown bucket"] unless Asset::BUCKETS.include?(bucket)

    company_ref = path_parts.shift
    company_ref = $1 if company_ref =~ /^(.+?)___/
    errors << [relative_path, "invalid company reference format"] unless company_ref =~ Company::REFERENCE_FORMAT

    name = path_parts.pop
    errors << [relative_path, "invalid asset name format"] unless name =~ Asset::NAME_FORMAT
    errors << [relative_path, "extension not jpg, pdf or png"] unless name =~ /(jpg|pdf|png)$/
    
    paths_by_name = (paths_by_names_by_company_refs[company_ref] ||= {})
    existing_path = paths_by_name[name]
    if existing_path.nil? then paths_by_name[name] = relative_path
    else errors << [relative_path, "duplicate of #{existing_path}"]
    end
    
    checksum = Digest::MD5.file(path).hexdigest
    
    variants = [nil, nil]
    variants = %w(small tiny).map do |variant|
      variant_path, error = create_asset_variant(path, checksum, variant)
      errors << [relative_path, error] unless error.nil?
      variant_path
    end if File.extname(path) =~ Asset::IMAGE_FORMAT
    
    assets << ([bucket, company_ref, name, path, checksum] + variants)
  end
  
  if errors.empty?
    FasterCSV.open(ASSET_CSV_PATH, "w") do |csv|
      csv << ["bucket", "company.reference", "name", "file_path", "checksum", "file_path_small", "file_path_tiny"]
      assets.sort.each { |asset| csv << asset }
    end
    return nil
  end
  
  FasterCSV.open(ASSET_ERRORS_PATH, "w") do |error_report|
    error_report << ["path", "error"]
    errors.each { |error| error_report << error }
  end
  ASSET_ERRORS_PATH
end

def create_asset_variant(source_path, checksum, variant)
  path = ASSET_VARIANT_DIR / "#{checksum}-#{variant}#{File.extname(source_path)}"
  return [File.size(path).zero? ? nil : path, nil] if File.exist?(path)
  
  width, height =
    case variant
    when "small" then [200, 200]
    when "tiny"  then [100, 100]
    else raise "unknown variant #{variant.inspect}"
    end
  
  begin
    ImageScience.with_image(source_path) do |img|
      unless img.width == 400 and img.height == 400
        FileUtils.touch(path)
        return [nil, nil]
      end
      img.resize(width, height) { |resized| resized.save(path) }    
    end
    [path, nil]
  rescue Exception => e
    [nil, "unable to create #{variant} variant: #{e}"]
  end
end

def mail(success, message, attachment_path = nil)
  puts "Import #{success} on #{`hostname`.chomp} (#{Merb.environment} environment)"
  puts message
  puts "attachment: #{attachment_path}" unless attachment_path.nil?
  # TODO: do not send mail if Merb.environment == "development"
  # system "open #{attachment_path}" if Merb.environment == "development"
end

def mail_fail(message, attachment_path = nil, exception = nil)
  message += "\n#{exception.inspect}" unless exception.nil?
  mail(:failure, message, attachment_path)
  exit 1
end

def repo_mtime(path)
  unix_stamp = `git --git-dir='#{path}/.git' log -n1 --pretty='format:%at'`
  Time.at(unix_stamp.to_i)
end

def repo_summary(path)
  `git --git-dir='#{path}/.git' log -n1 --pretty='format:%ai: %s'`.chomp
end

def stopwatch(message)
  start = Time.now
  result = yield
  puts "#{'%6.2f' % (Time.now - start)}s : #{message}"
  result
end


# Ensure that GraphicsMagick is installed

mail_fail("Failed to locate the 'gm' tool - is GraphicsMagick installed?") if `which gm`.blank?


# Ensure each class has an associated parser

parsers_by_class = {}
CLASSES.each do |klass|
  begin
    require "lib/parsers/#{klass.to_s.snake_case}"
    parsers_by_class[klass] = Kernel.const_get("#{klass}Parser")
  rescue Exception => e
    mail_fail("Failed to locate parser for #{klass}.", nil, e)
  end
end


# Build an asset import CSV from the contents of the asset repo

puts "=== Building Asset CSV ==="
stopwatch("assets.csv") do
  error_message = "Failed to build asset CSV from asset repository #{ASSET_REPO.inspect}."
  begin
    error_report_path = build_asset_csv
    mail_fail(error_message, error_report_path) unless error_report_path.nil?
  rescue SystemExit
    exit 1
  rescue Exception => e
    mail_fail(error_message, nil, e)
  end
end


# Ensure each class has at least one associated CSV to be imported

csv_paths_by_class = {}
errors = []
CLASSES.each do |klass|
  stub = (klass == Asset ? "/tmp" : CSV_REPO) / klass.storage_name

  if File.directory?(stub)
    paths = Dir[stub / "*.csv"]
    if paths.empty? then errors << "No CSVs found for #{klass} in #{stub.inspect}."
    else csv_paths_by_class[klass] = paths
    end
  else
    path = "#{stub}.csv"
    if File.exist?(path) then csv_paths_by_class[klass] = [path]
    else errors << "No CSV found for #{klass} at #{path.inspect}"
    end
  end
end

mail_fail(errors.join("\n")) unless errors.empty?


# Parse each class

puts "=== Parsing CSVs ==="
import_set = ImportSet.new
CLASSES.each do |klass|
  parser = parsers_by_class[klass].new(import_set)
  csv_paths_by_class[klass].each do |path|
    nice_path = File.basename(path)
    nice_path = File.basename(File.dirname(path)) / nice_path unless nice_path == "#{klass.storage_name}.csv"
    stopwatch(nice_path) { parser.parse(path) }
  end
end

puts "=== Verifying Global Integrity ==="
import_set.verify_integrity

mail_fail("Some errors occurred whilst parsing CSVs from #{CSV_REPO.inspect} (and the auto-generated /tmp/assets.csv).", "/tmp/errors.csv") if import_set.write_errors("/tmp/errors.csv")


# Import the entire set

puts "=== Importing Objects ==="
class_stats = import_set.import

mail_fail("Some errors occurred whilst importing objects defined in CSVs from #{CSV_REPO.inspect} (and the auto-generated /tmp/assets.csv).", "/tmp/errors.csv") if import_set.write_errors("/tmp/errors.csv")

report = ["Asset repository @ #{repo_summary(ASSET_REPO)}", "CSV repository @ #{repo_summary(CSV_REPO)}", ""]
report += class_stats.map do |klass, stats|
  "#{klass}: " + [:created, :updated, :destroyed, :skipped].map do |stat|
    count = stats[stat]
    count.zero? ? nil : "#{stat} #{count}"
  end.compact.join(", ")
end

report = report.join("\n")
ImportEvent.create(:succeeded => true, :report => report)
mail(:success, report)

puts "=== Compiling Indexes ==="
stopwatch(Indexer::COMPILED_PATH) do
  Indexer.compile
  CachedFind.all.update!(:invalidated => true)
  PickedProduct.all.update!(:invalidated => true)
end
