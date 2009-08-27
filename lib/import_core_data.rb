# merb -i -r "lib/import_core_data"

require "lib/parsers/abstract"

ASSET_REPO = "../ifloat_assets"
CSV_REPO = "../ifloat_csvs"

CLASSES = [PropertyType, PropertyDefinition, PropertyValueDefinition, TitleStrategy, Company, Facility, Asset, DefinitiveProduct]

class ImportObject
  attr_accessor :primary_key, :resource
  attr_reader :klass, :attributes, :path, :row
  
  def initialize(klass, attributes)
    @klass = klass
    @attributes = attributes
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
    DefinitiveProduct       => [:company, :reference],
    Attachment              => [:product, :role, :sequence_number],
    ProductMapping          => [:company, :product, :reference],
    Relationship            => [:company, :product, :property_definition, :name, :value],
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
    raise "add cannot be called once import has been" if @objects_by_pk_by_class.nil?
    
    @objects << object
    
    pk = object.primary_key = object.attributes.values_at(*PRIMARY_KEYS[object.klass])
    error(object.klass, object.path, object.row, nil, "unable to establish primary key") if pk.nil?
    return if pk.nil? or pk.any? { |v| v.nil? }
    
    objects_by_pk = (@objects_by_pk_by_class[object.klass] ||= {})
    existing = objects_by_pk[pk]
    
    if existing.nil? then objects_by_pk[pk] = object
    else error(object.klass, object.path, object.row, nil, "duplicate of #{existing.path} row #{existing.row}: #{friendly_pk(pk)}")
    end
  end
  
  def error(klass, path, row, column, message)
    @errors << [klass, path, row, column, message]
  end
  
  def get(klass, *pk_value)
    (@objects_by_pk_by_class[klass] || {})[pk_value]
  end
  
  def get!(klass, *pk_value)
    object = get(klass, *pk_value)
    raise "invalid/unknown #{klass}: #{friendly_pk(pk_value)}" if object.nil?
    object
  end
  
  def import
    @objects_by_pk_by_class = nil
    
    classes = []
    objects_by_class = {}
    
    @objects.each do |object|
      klass = object.klass
      classes << klass unless classes.include?(klass)
      (objects_by_class[klass] ||= []) << object
    end
    
    DataMapper.repository(:default) do
      default_adapter = DataMapper.repository(:default).adapter
      transaction = DataMapper::Transaction.new(default_adapter)
      transaction.begin
      default_adapter.push_transaction(transaction)
      
      classes.each do |klass|
        start = Time.now
        import_class(klass, objects_by_class[klass])
        puts "#{'%6.2f' % (Time.now - start)}s : #{klass}"
      end

      default_adapter.pop_transaction
      if @errors.empty? then transaction.commit
      else transaction.rollback
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
    product_relationship = klass.relationships[:product]
    product_key = product_relationship.nil? ? nil : product_relationship.child_key.first.name
    
    existing_by_pk = {}
    resource_pk = PRIMARY_KEYS[klass]
    klass.all.each do |resource|
      pk = resource_pk.map do |attribute|
        attribute == :product ? DefinitiveProduct.get(resource.send(product_key)) : resource.send(attribute)
      end
      existing_by_pk[pk] = resource
    end
    
    to_save = []
    to_skip = []
    
    objects.each do |object|
      pk = object.primary_key
      pk.map! { |v| v.is_a?(ImportObject) ? v.resource : v }
      existing = existing_by_pk[pk]
      
      attributes = {}
      object.attributes.each do |key, value|
        attributes[key] = (value.is_a?(ImportObject) ? value.resource : value)
      end
      
      object.resource = (existing || klass.new)
      object.resource.attributes = attributes
      (object.resource.dirty? ? to_save : to_skip) << object
    end
    
    to_destroy = existing_by_pk.values.map { |r| r.id } - (to_save + to_skip).map { |o| o.resource.id }
    
    # TODO: review whether we need chained destruction behavior anywhere
    klass.all(:id => to_destroy).destroy! unless to_destroy.empty?
    
    to_save.each do |object|
      next if object.resource.save
      object.resource.errors.full_messages.each { |message| error(klass, object.path, object.row, nil, message) }
    end
  end
end

def build_asset_csv
  assets = []
  errors = []
  
  Dir[ASSET_REPO / "**" / "*"].each do |path|
    next unless File.file?(path)
    
    raise "unable to extract relative path from #{path.inspect}" unless path =~ /^#{ASSET_REPO}\/(.+)/
    relative_path = $1
    path_parts = relative_path.split("/")
    
    unless (3..4).include?(path_parts.size)
      errors << [relative_path, "not in a bucket/company or bucket/company/todo_note directory"]
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
    
    assets << [bucket, company_ref, name, path_parts.first, path]
  end
  
  if errors.empty?
    FasterCSV.open("/tmp/assets.csv", "w") do |csv|
      csv << ["bucket", "company.reference", "name", "todo_notes", "file_path"]
      assets.each { |asset| csv << asset }
    end
    return nil
  end
  
  error_report_path = "/tmp/basic_asset_errors.csv"
  FasterCSV.open("/tmp/basic_asset_errors.csv", "w") do |error_report|
    error_report << ["path", "error"]
    errors.each { |error| error_report << error }
  end
  error_report_path
end

def mail(success, message, attachment_path = nil)
  puts "Import #{success} on #{`hostname`.chomp}"
  puts message
  puts "attachment: #{attachment_path}" unless attachment_path.nil?
  # TODO: do not send mail if Merb.environment == "development"
  system "open #{attachment_path}" if Merb.environment == "development"
end

def mail_fail(message, attachment_path = nil, exception = nil)
  message += "\n#{exception.inspect}" unless exception.nil?
  mail(:failure, message, attachment_path)
  exit 1
end


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
start = Time.now
error_message = "Failed to build asset CSV from asset repository #{ASSET_REPO.inspect}."
begin
  error_report_path = build_asset_csv
  mail_fail(error_message, error_report_path) unless error_report_path.nil?
rescue SystemExit
  exit 1
rescue Exception => e
  mail_fail(error_message, nil, e)
end
puts "#{'%6.2f' % (Time.now - start)}s : /tmp/assets.csv"


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
    start = Time.now
    parser.parse(path)
    nice_path = File.basename(path)
    nice_path = File.basename(File.dirname(path)) / nice_path unless nice_path == "#{klass.storage_name}.csv"
    puts "#{'%6.2f' % (Time.now - start)}s : #{nice_path}"
  end
end

if import_set.write_errors("/tmp/errors.csv")
  mail_fail("Some errors occurred whilst parsing CSVs from #{CSV_REPO.inspect} (and the auto-generated /tmp/assets.csv).", "/tmp/errors.csv")
end


# Import the entire set

puts "=== Importing Objects ==="
import_set.import

if import_set.write_errors("/tmp/errors.csv")
  mail_fail("Some errors occurred whilst importing objects defined in CSVs from #{CSV_REPO.inspect} (and the auto-generated /tmp/assets.csv).", "/tmp/errors.csv")
end
