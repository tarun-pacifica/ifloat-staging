# merb -i -r lib/import_core_data.rb

require "lib/parsers/abstract"

ASSET_CSV_PATH = "/tmp/assets.csv"
ASSET_REPO = "../ifloat_assets"
ASSET_VARIANT_DIR = "/tmp/ifloat_asset_variants"
FileUtils.mkpath(ASSET_VARIANT_DIR)
ASSET_VARIANT_SIZES = {:small => "200x200", :tiny => "100x100"}
ASSET_WATERMARK_PATH = "public/images/common/watermark.png"
ASSET_WATERMARK_PATH_LARGE = "public/images/common/watermark_large.png"

CSV_DUMP_DIR = "/tmp/ifloat_csv_dumps"
FileUtils.mkpath(CSV_DUMP_DIR)
CSV_REPO  = "../ifloat_csvs"

ERRORS_PATH = "/tmp/errors.csv"
TITLE_REPORT_PATH = "/tmp/titles.csv"

CLASSES = [PropertyType, PropertyDefinition, PropertyValueDefinition, AssociatedWord, TitleStrategy, UnitOfMeasure, Company, Facility, Asset, Brand, Product]

class ImportObject
  attr_accessor :primary_key, :resource_id
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
    AssociatedWord          => [:word, :rules],
    TitleStrategy           => [:name],
    UnitOfMeasure           => [:class_name],
    Company                 => [:reference],
    Facility                => [:company, :name],
    Asset                   => [:bucket, :company, :name],
    Brand                   => [:company, :name],
    Product                 => [:company, :reference],
    Attachment              => [:product, :role, :sequence_number],
    ProductMapping          => [:company, :product, :reference],
    ProductRelationship     => [:company, :product, :property_definition, :name, :value],
    DatePropertyValue       => [:product, :definition, :sequence_number],
    NumericPropertyValue    => [:product, :definition, :sequence_number, :unit],
    TextPropertyValue       => [:product, :definition, :sequence_number, :language_code]
  }
  
  BULK_CLASSES = [AssociatedWord, Attachment, ProductMapping, ProductRelationship, DatePropertyValue, NumericPropertyValue, TextPropertyValue].to_set
  
  def initialize
    @errors = []
    @objects = []
    @objects_by_pk_by_class = {}
    @objects_checkpoint = 0
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
  
  def add_from_dump(name)
    objects = Marshal.load(File.open(dump_path(name))).each do |object|
      object, error = marshal_unisolate(object)
      
      if error.nil? then add(object)
      else error(object.klass, object.path, object.row, nil, error) # TODO: column is not reported on cached items
      end
    end
  end
  
  def checkpoint
    @errors_checkpoint = @errors.size
    @objects_checkpoint = @objects.size
  end
  
  def dump_exists?(name)
    File.exist?(dump_path(name))
  end
  
  def dump_from_checkpoint(name)
    objects = @objects[@objects_checkpoint..-1]
    Marshal.dump(objects.map { |object| marshal_isolate(object) }, File.open(dump_path(name), "w"))
  end
  
  def dump_path(name)
    CSV_DUMP_DIR / name
  end
  
  def error(klass, path, row, column, message)
    @errors << [klass, path, row, column, message]
  end
  
  def errors_since_checkpoint?
    @errors.size > @errors_checkpoint
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
      classes << klass
      (objects_by_class[klass] ||= []) << object
    end
    
    class_stats = []
    
    DataMapper.repository(:default) do
      @adapter = DataMapper.repository(:default).adapter
      transaction = DataMapper::Transaction.new(@adapter)
      transaction.begin
      @adapter.push_transaction(transaction)
      
      classes.uniq.each do |klass|
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
    
    all_products = @objects.select { |object| object.klass == Product }
    error(Product, nil, nil, nil, "> 50,000 products (sitemap would be invalid)") if all_products.size > 50000
    
    stopwatch("ensured all products have a 400x400 primary image") do
      (all_products - pias_by_product.keys).each do |product|
        error(Product, product.path, product.row, nil, "no primary image specified")
      end
      
      pias_by_product.values.map { |attachment| attachment.attributes[:asset] }.uniq.each do |asset|
        pk = asset.primary_key
        size = asset.attributes[:pixel_size]
        error(Asset, asset.path, asset.row, nil, "not 400x400 (#{size}): #{friendly_pk(pk)}") unless size == "400x400"
      end
    end
    
    stopwatch("handled orphaned PickedProducts") do
      db_companies = Company.all.hash_by(:reference)
      orphaned_product_ids = []
      
      PickedProduct.all_primary_keys.each do |company_ref, product_ref|
        company = get(Company, company_ref)
        if company.nil?
          error(Company, nil, nil, nil, "unable to delete company with user-referenced product: #{company_ref} / #{product_ref}")
        elsif get(Product, company, product_ref).nil?
          orphaned_product_ids << db_companies[company_ref].products.first(:reference => product_ref).id
        end
      end
      
      PickedProduct.handle_orphaned(orphaned_product_ids) if orphaned_product_ids.any? and @errors.empty?
    end
    
    stopwatch("ensured no orphaned Purchases") do
      Purchase.all_facility_primary_keys.each do |company_ref, facility_url|
        company = get(Company, company_ref)
        if company.nil?
          error(Company, nil, nil, nil, "unable to delete company with facility with user-referenced purchases: #{company_ref} / #{facility_url}")
        elsif get(Facility, company, facility_url).nil?
          error(Facility, nil, nil, nil, "unable to delete facility with user-referenced purchases: #{company_ref} / #{facility_url}")
        end
      end
    end
    
    text_values = @objects.select { |o| o.klass == TextPropertyValue }
    
    stopwatch("ensured no blank summaries") do
      property = get!(PropertyDefinition, "marketing:summary")
      products_with_summaries = text_values.map { |tv| tv.attributes[:definition] == property ? tv.attributes[:product] : nil }.compact.uniq
      (all_products - products_with_summaries).each do |product|
        error(Product, product.path, product.row, "marketing:summary", "value required")
      end
    end
    
    stopwatch("ensured no blank / invalid category values") do
      properties = %w(reference:class_senior reference:class).map! { |key| get!(PropertyDefinition, key) }.to_set
      
      properties_by_product = {}
      text_values.each do |tv|
        product, property, value = tv.attributes.values_at(:product, :definition, :text_value)
        next unless properties.include?(property)
        (properties_by_product[product] ||= []) << property
        error(Product, product.path, product.row, property.attributes[:name], "value may only contain (a-z, hyphens or spaces): #{value.inspect}") unless value =~ /^[A-Za-z\- ]+$/
      end
      
      properties_by_product.each do |product, prod_props|
        (properties - prod_props).each do |property|
          error(Product, product.path, product.row, property.attributes[:name], "value required")
        end
      end
    end
    
    # TODO: generalize to non-English titles when ready
    stopwatch("ensured no blank / duplicated titles and produced report") do
      at, rc = %w(auto:title reference:class).map! { |key| get!(PropertyDefinition, key) }
      values_by_heading_by_product = {}
      
      text_values.each do |tv|
        property = tv.attributes[:definition]
        next unless property == at or property == rc
        
        product = tv.attributes[:product]
        values_by_heading = (values_by_heading_by_product[product] ||= {
          "company.reference" => product.attributes[:company].attributes[:reference],
          "product.reference" => product.attributes[:reference]
        })
        heading =
          if property == rc then "reference:class"
          else TitleStrategy::TITLE_PROPERTIES[tv.attributes[:sequence_number] - 1]
          end
        values_by_heading[heading] = tv.attributes[:text_value]
      end
      
      first_product_by_value_by_heading = {}
      values_by_heading_by_product.each do |product, values_by_heading|
        TitleStrategy::TITLE_PROPERTIES.each do |title|
          value = values_by_heading[title]
          if value.blank?
            error(Product, product.path, product.row, nil, "empty #{title} title")
            next
          end
          
          next if title == :image
          
          first_product_by_value = (first_product_by_value_by_heading[title] ||= {})
          collision = first_product_by_value[value]
          if collision.nil? then first_product_by_value[value] = product
          else error(Product, product.path, product.row, nil, "duplicates #{title} title from #{collision.path} row #{collision.row} (#{friendly_pk(collision.primary_key)}): #{value}")
          end
        end
      end
      
      headings = %w(reference:class company.reference product.reference) + TitleStrategy::TITLE_PROPERTIES
      FasterCSV.open(TITLE_REPORT_PATH, "w") do |title_report|
        title_report << headings
        values_by_heading_by_product.each do |product, values_by_heading|
          title_report << values_by_heading.values_at(*headings)
        end
      end
    end
    
    stopwatch("ensured no missing marinestore.co.uk product variants") do
      require "lib" / "partners" / "marine_store"
      marine_store = get!(Company, "GBR-02934378")
      mappings = @objects.select { |o| o.klass == ProductMapping and o.attributes[:company] == marine_store }
      references = mappings.map { |m| m.attributes[:reference] }.to_set
      from_xml_path = CSV_REPO / "partners" / "marinestore.co.uk" / "provide.xml"
      to_csv_path = "/tmp/ms_variant_refs_missing.csv"
      missing = Partners::MarineStore.dump_report(from_xml_path, to_csv_path) { |ref| not references.include?(ref) }
      warn "#{missing} marinestore.co.uk references missing: #{to_csv_path}" if missing > 0
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
    GC.enable if [TextPropertyValue, NumericPropertyValue].include?(klass) # TODO: remove once GC trickery is defunct
    
    relationships = {}
    klass.relationships.each do |attribute, relationship|
      relationships[attribute.to_sym] = relationship.child_key.first.name
    end
    
    pk_fields, value_fields = pk_and_value_fields(klass)
    existing_catalogue = value_md5s_and_ids_by_pk_md5(klass, pk_fields, value_fields)
    
    skipped_pk_md5s = []
    to_create = []
    to_update = []
    
    objects.each do |object|
      attributes = {}
      object.attributes.each do |key, value|
        key = relationships[key] if relationships.has_key?(key)
        attributes[key] = (value.is_a?(ImportObject) ? value.resource_id : value)
      end
      
      pk = attributes.values_at(*pk_fields)
      pk.map! { |k| k.is_a?(Hash) ? Base64.encode64(Marshal.dump(k)) : k }
      pk_md5 = Digest::MD5.hexdigest(pk.join("::"))
      existing_value_md5, existing_id = existing_catalogue[pk_md5]
      to_create << [pk_md5, object, attributes] and next if existing_id.nil?

      object.resource_id = existing_id
      
      values = value_fields.map do |attribute|
        value = attributes[attribute]
        value = "%.6f" % value if attribute == :min_value or attribute == :max_value
        
        case value
        when Array, Hash then Base64.encode64(Marshal.dump(value))
        when FalseClass, TrueClass then value ? 1 : 0
        else value
        end
      end
      
      value_md5 = (values.empty? ? nil : Digest::MD5.hexdigest(values.join("::")))
      if value_md5 == existing_value_md5 then skipped_pk_md5s << pk_md5
      else to_update << [pk_md5, object, attributes]
      end
    end
    
    to_update_ids = to_update.map { |pk_md5, obj, attr| obj.resource_id }
    resources_by_id = klass.all(:id => to_update_ids).hash_by(:id)
    
    to_keep_pk_md5s = skipped_pk_md5s + (to_create + to_update).map { |pk_md5, object, attributes| pk_md5 }
    to_destroy_pk_md5s = (existing_catalogue.keys - to_keep_pk_md5s)
    to_destroy_ids = existing_catalogue.values_at(*to_destroy_pk_md5s).map { |value_md5, id| id }
    to_destroy_ids.each_slice(1000) { |ids| klass.all(:id => ids).destroy! }
    stats = {:created => 0, :updated => 0, :destroyed => to_destroy_ids.size, :skipped => skipped_pk_md5s.size}
    
    if BULK_CLASSES.include?(klass)
      table_name = @adapter.send(:quote_name, klass.storage_name)
      
      properties = klass.properties
      properties.delete(klass.serial)
      
      bind_set = "(" + Array.new(properties.size) { "?" }.join(", ") + ")"
      column_names = properties.map { |property| property.name }
      column_names_list = column_names.map { |name| @adapter.send(:quote_name, name.to_s) }.join(", ")
      
      to_create.each_slice(1000) do |slice|
        bind_sets = Array.new(slice.size) { bind_set }.join(", ")
        bind_values = []
        slice.each do |pk_md5, object, attributes|
          attributes[:type] = klass
          attributes.values_at(*column_names).each do |v|
            bind_values << ((v.is_a?(Array) or v.is_a?(Hash)) ? Base64.encode64(Marshal.dump(v)) : v)
          end
        end
        
        begin
          @adapter.execute("INSERT INTO #{table_name} (#{column_names_list}) VALUES #{bind_sets}", *bind_values)
          stats[:created] += slice.size
        rescue Exception => e
          error(klass, nil, nil, nil, e.message)
          return stats
        end
      end
      
      to_create.clear
    end
    
    (to_create + to_update).each do |pk_md5, object, attributes|
      res_id = object.resource_id
      resource = (res_id.nil? ? klass.new : resources_by_id[res_id])
      resource.attributes = attributes
      
      action = (res_id.nil? ? :created : :updated)
      errors = nil
      begin
        if resource.save then object.resource_id ||= resource.id
        else errors = resource.errors.full_messages
        end
      rescue Exception => e
        errors = [e.message]
      end
    
      unless errors.nil?
        errors.each { |message| error(klass, object.path, object.row, nil, message) }
        action = :skipped
      end
    
      stats[action] += 1
    end
    stats
  end
  
  def marshal_isolate(object)
    isolated_attributes = {}
    object.attributes.each do |key, value|
      isolated_attributes[key] = (value.is_a?(ImportObject) ? marshal_isolate_parent(value) : value)
    end    
    [object.klass, object.path, object.row, isolated_attributes]
  end
  
  def marshal_isolate_parent(object)
    pk_value = object.primary_key.map { |value| value.is_a?(ImportObject) ? marshal_isolate_parent(value) : value }
    [object.klass, pk_value]
  end
  
  def marshal_unisolate(isolated_object)
    klass, path, row, isolated_attributes = isolated_object
    
    attributes = {}
    error = nil
    begin
      isolated_attributes.each do |key, value|        
        value = marshal_unisolate_parent(*value) if value.is_a?(Array) and value.first.is_a?(Class)
        attributes[key] = value
      end
    rescue Exception => e
      error = e.message
    end
    
    object = ImportObject.new(klass, attributes)
    object.set_source(path, row)
    [object, error]
  end
  
  def marshal_unisolate_parent(klass, pk_value)
    pk_value.map! do |value|
      (value.is_a?(Array) and value.first.is_a?(Class)) ? marshal_unisolate_parent(*value) : value
    end
    get!(klass, *pk_value)
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
  stopwatch("catalogued assets") do
    Dir[ASSET_REPO / "**" / "*"].each do |path|
      next unless File.file?(path)
      
      raise "unable to extract relative path from #{path.inspect}" unless path =~ /^#{ASSET_REPO}\/(.+)/
      relative_path = $1
      path_parts = relative_path.split("/")
      
      unless (3..4).include?(path_parts.size)
        errors << [relative_path, "not in a bucket/company or bucket/company/class directory"]
        next
      end
      
      errors << [relative_path, "empty file"] if File.size(path) == 0
      
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
      assets << [bucket, company_ref, name, path, checksum]
    end
  end
  return errors unless errors.empty?
  
  stopwatch("catalogued image sizes") do
    assets_by_path = assets.hash_by { |bucket, company_ref, name, path, checksum| path }
    assets_by_path.keys.map { |k| k =~ /(jpg|png)$/ ? k.inspect : nil }.compact.each_slice(500) do |paths|
      `gm identify #{paths.join(" ")} 2>&1`.lines.each do |line|
        unless line =~ /^(.+?\.(jpg|png)).*?(\d+x\d+)/
          errors <<  [nil, "unable to read GM.identify report line: #{line.inspect}"]
          next
        end

        asset = assets_by_path[$1]
        if asset.nil? then errors << [nil, "unable to associate GM.identify report line: #{line.inspect}"]
        else asset << $3
        end
      end
    end
  end
  return errors unless errors.empty?
  
  wm_exists = File.exists?(ASSET_WATERMARK_PATH)
  stopwatch("created missing image variants") do
    assets.each do |info|
      bucket, company_ref, name, path, checksum, size = info
      next if size.nil? or bucket != "products"

      ext = File.extname(path)
      
      wm_path = path
      if wm_exists
        wm_path = info[3] = ASSET_VARIANT_DIR / "#{checksum}#{ext}"
        unless File.exist?(wm_path)
          placement = (size == "400x400" ? "-geometry +10+10 -gravity SouthEast" : "-gravity Center")
          report = `gm composite #{placement} #{ASSET_WATERMARK_PATH.inspect} #{path.inspect} #{wm_path.inspect} 2>&1`
          unless $?.success?
            errors << [path, "GM.composite failed: #{report.inspect}"]
            next
          end
        end
      end

      next unless size == "400x400"    
      [:small, :tiny].map do |variant|
        variant_path = ASSET_VARIANT_DIR / "#{checksum}-#{variant}#{ext}"
        info << variant_path
        next if File.exist?(variant_path)
      
        variant_size = ASSET_VARIANT_SIZES[variant]
        report = `gm convert -size #{variant_size} #{wm_path.inspect} -resize #{variant_size} +profile '*' #{variant_path.inspect} 2>&1`
        errors << [path, "GM.convert failed: #{report.inspect}"] unless $?.success?
      end
    end
  end
  return errors unless errors.empty?
  
  stopwatch("assets.csv") do
    FasterCSV.open(ASSET_CSV_PATH, "w") do |csv|
      csv << ["bucket", "company.reference", "name", "file_path", "checksum", "pixel_size", "file_path_small", "file_path_tiny"]
      assets.sort.each { |asset| csv << asset }
    end
  end
  nil
end

def mail_fail(whilst)
  Mailer.deliver(:import_failure, :ars => repo_summary(ASSET_REPO),
                                  :crs => repo_summary(CSV_REPO),
                                  :whilst => whilst,
                                  :attach => ERRORS_PATH) unless Merb.environment == "development"
  puts "ERROR whilst #{whilst} - emailed report: #{ERRORS_PATH}"
  exit 1
end

def repo_mtime(path)
  unix_stamp = `git --git-dir='#{path}/.git' log -n1 --pretty='format:%at'`
  Time.at(unix_stamp.to_i)
end

def repo_summary(path)
  `git --git-dir='#{path}/.git' log -n1 --pretty='format:%ai: %s'`.chomp
end

# TODO: remove GC directives if they no longer give a 3x-4x speed boost in 1.9
def memory_usage_kb; `ps -o rss= -p #{Process.pid}`.to_i; end

def stopwatch(message)
  GC.disable if memory_usage_kb < 2 ** 20
  start = Time.now
  result = yield
  puts "#{'%6.2f' % (Time.now - start)}s : #{message}"
  GC.enable
  result
end


# Disable DM's identity map for the duration of this script

module DataMapper::Resource
  private
  def add_to_identity_map; end
end


# Ensure that GraphicsMagick is installed

raise "Failed to locate the 'gm' tool - is GraphicsMagick installed?" if `which gm`.blank?


# Ensure each class has an associated parser

parsers_by_class = {}
CLASSES.each do |klass|
  begin
    require "lib/parsers/#{klass.to_s.snake_case}"
    parsers_by_class[klass] = Kernel.const_get("#{klass}Parser")
  rescue Exception => e
    raise "Failed to locate parser for #{klass}: #{e}"
  end
end


# Build an asset import CSV from the contents of the asset repo

puts "=== Compiling Assets ==="
errors = build_asset_csv
unless errors.nil?
  FasterCSV.open(ERRORS_PATH, "w") do |error_report|
    error_report << ["path", "error"]
    errors.each { |error| error_report << error }
  end
  mail_fail("compiling assets")
end


# Ensure each class has at least one associated CSV to be imported

csv_paths_by_class = {}
errors = []
CLASSES.each do |klass|
  stub = (klass == Asset ? "/tmp" : CSV_REPO) / klass.storage_name

  if File.directory?(stub)
    paths = Dir[stub / "*.csv"].sort
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
unless errors.empty?
  FasterCSV.open(ERRORS_PATH, "w") do |error_report|
    error_report << ["error"]
    errors.each { |error| error_report << error }
  end
  mail_fail("checking for missing CSVs")
end


# Parse each class

puts "=== Parsing CSVs ==="
dump_paths = []
freshly_parsed_classes = Set.new
import_set = ImportSet.new
CLASSES.each do |klass|
  # TODO: remove once the corresponding get in the product parser is removed
  next if klass == Product and import_set.get(Company, "GBR-02934378").nil?
  
  parser = parsers_by_class[klass].new(import_set)
  csv_paths_by_class[klass].each do |path|
    nice_path = File.basename(path)
    nice_path = File.basename(File.dirname(path)) / nice_path unless nice_path == "#{klass.storage_name}.csv"
    
    checksum = Digest::MD5.file(path).hexdigest
    dump_name = "#{nice_path}_#{checksum}.dump".tr("/", "_")
    dump_paths << import_set.dump_path(dump_name)
    
    load_from_cache = import_set.dump_exists?(dump_name)
    load_from_cache = false if klass == Product and not (freshly_parsed_classes & [PropertyType, TitleStrategy]).empty?
    load_from_cache = false if klass == TitleStrategy and freshly_parsed_classes.include?(PropertyDefinition)
    
    if load_from_cache
      stopwatch("#{nice_path} [cached]") { import_set.add_from_dump(dump_name) }
    else
      import_set.checkpoint
      stopwatch(nice_path) { parser.parse(path) }
      if import_set.errors_since_checkpoint? then puts "          --> errors detected [cache not updated]"
      else stopwatch("--> [updated cache]") { import_set.dump_from_checkpoint(dump_name) }
      end
      freshly_parsed_classes << klass
    end
  end
end
mail_fail("parsing CSVs") if import_set.write_errors(ERRORS_PATH)


# Verify global integrity

puts "=== Verifying Global Integrity ==="
import_set.verify_integrity
mail_fail("verifying data integrity") if import_set.write_errors(ERRORS_PATH)


# Import the entire set

puts "=== Updating Database ==="
class_stats = import_set.import
mail_fail("updating the database") if import_set.write_errors(ERRORS_PATH)
Mailer.deliver(:import_success, :ars => repo_summary(ASSET_REPO), :crs => repo_summary(CSV_REPO), :stats => class_stats)  unless Merb.environment == "development"

begin; stopwatch("destroyed obsolete assets") { AssetStore.delete_obsolete }; rescue; end
stopwatch("destroyed obsolete CSV dumps") { File.delete(*(Dir[CSV_DUMP_DIR / "*.dump"] - dump_paths)) }

puts "=== Compiling Indexes ==="
stopwatch(Indexer::COMPILED_PATH) do
  GC.enable # TODO: remove once GC trickery is defunct
  Indexer.compile
  CachedFind.all.update!(:invalidated => true)
  PickedProduct.all.update!(:invalidated => true)
end
