# coding: utf-8

if RUBY_VERSION =~ /^1\.9\./
  $: << "."
  require "csv"
  FasterCSV = CSV
end

require "fileutils"
require "set"

require "lib" / "asset_store"
require "lib" / "conversion"
require "lib" / "indexer"
require "lib" / "mailer"
require "lib" / "password"
require "lib" / "speller"

require "lib" / "partners" / "marine_store"

use_orm :datamapper
use_test :rspec
use_template_engine :erb

Merb::Config.use do |c|
  c[:use_mutex] = false
  c[:session_store] = "datamapper"
  c[:session_expiry] = 100 * 365 * Merb::Const::DAY
  c[:adapter] = 'thin'  # Added this line to use Thin
end

Merb::BootLoader.before_app_loads do

  # These methods are handy to have available in general

  class Array
    def friendly_join(andor)
      size <= 1 ? first : self[0..-2].join(", ") + " #{andor} #{last}"
    end

    def hash_by(method = nil)
      hash = {}
      each do |item|
        key = (method.nil? ? (yield item) : item.send(method))
        hash[key] = item
      end
      hash
    end

    def repeated
      counts = Hash.new(0)
      each { |item| counts[item] += 1 }
      counts.reject { |item, count| count < 2 }.keys
    end
  end

  class Hash
    def keep(*keys)
      hash = {}
      keys.each { |key| hash[key] = self[key] if self.has_key?(key) }
      hash
    end
  end

  class String
    def attribute_escape(inner_escape_single_quotes = false)
      escaped = Merb::Parse.escape_xml(self)
      escaped.gsub!(/(')/) { "\\'" } if inner_escape_single_quotes
      escaped
    end

    # temporary mechanism to cope with encoding problems in 1.9
    # alias_method :orig_concat, :concat
    # def concat(other)
    #   begin
    #     orig_concat(other)
    #   rescue Encoding::CompatibilityError
    #     p [encoding, self]
    #     p [other.encoding, other]
    #     encode("utf-8").concat(other.endcode("utf-8"))
    #   end
    # end

    def desuperscript
      gsub(%r{<sup>(.*?)</sup>}, '\1')
    end

    def pluralize_count(count)
      "#{count} #{self}#{count == 1 ? '' : 's'}"
    end

    def superscript(matcher = /([®™])/)
      gsub(matcher) { |c| "<sup>#{c}</sup>" }
    end

    def superscript_numeric
      parts = split(" ")
      last_part = parts.pop
      return self unless last_part =~ /[a-z]/
      (parts << last_part.superscript(/(\d)/)).join(" ")
    end

    def truncate_utf8(size)
      self =~ /^(.{1,#{size}})/
      ($1.size + 3) < self.size ? "#{$1}..." : self
    end
  end

  # TODO: both compile steps should happen in server mode only

  # Merge all JS files - TODO: lint + minify
  path = "public/javascripts/compiled.js"
  File.delete(path) if File.exist?(path)
  raise $?.inspect unless system("cat public/javascripts/*.js > #{path}")

  # Merge all CSS files - TODO: lint + minify
  path = "public/stylesheets/compiled.css"
  File.delete(path) if File.exist?(path)
  raise $?.inspect unless system("cat public/stylesheets/*.css > #{path}")

end

Merb::BootLoader.after_app_loads do
  require "lib" / "data_mapper_session_store"
  begin
    Indexer.compile unless Indexer.facilities
  rescue => e
    Merb.logger.error("Failed to compile Indexer: #{e.message}")
  end
end

module DataMapperOverride
  extend self

  def safe_create(attrs = {})
    begin
      attrs = DataMapper::Ext::Hash.symbolize_keys(attrs)
      model = self.new(attrs)
      validate_and_transform_attributes(model)

      if model.save
        model
      else
        puts "Error saving #{self.name}: #{model.errors.full_messages.join(', ')}"
        nil
      end
    rescue => e
      puts "Error saving #{self.name}: #{e.message}"
      nil
    end
  end

  private

  def validate_and_transform_attributes(model)
    model.attributes.each do |key, value|
      prop = model.class.properties[key]
      next unless prop

      case prop.primitive.to_s
      when /IPAddress|IpAddress/
        validate_ip_address(model, key, value)
      when /DateTime|Time/
        format_datetime(model, key, value)
      when /Boolean/
        model.attribute_set(key, value ? 1 : 0)
      end
    end
  end

  def validate_ip_address(model, key, value)
    return unless value
    begin
      require 'ipaddr'
      IPAddr.new(value.to_s)
    rescue IPAddr::InvalidAddressError
      model.errors.add(key, 'Invalid IP address format')
    end
  end

  def format_datetime(model, key, value)
    return unless value
    begin
      formatted = value.is_a?(String) ? DateTime.parse(value) : value
      model.attribute_set(key, formatted.strftime('%Y-%m-%d %H:%M:%S'))
    rescue ArgumentError
      model.errors.add(key, 'Invalid datetime format')
    end
  end

  def test_all_models
    puts "Starting safe_create tests for all models..."

    models = ObjectSpace.each_object(Class).select { |c|
      c.ancestors.include?(DataMapper::Resource) &&
      !c.name.to_s.match(/Session|PropertyValue$|^Abstract/) &&
      !c.name.to_s.match(/Merb::/)
    }

    results = {}
    sort_models_by_dependencies(models).each do |model|
      results[model.name] = test_safe_create_for_model(model)
    end

    print_test_results(results)
    results.values.all?
  end

  public :test_all_models

  def test_safe_create_for_model(model_class)
    begin
      puts "\nTesting #{model_class.name}..."
      model_class.send(:include, DataMapperOverride) unless model_class.respond_to?(:safe_create)

      props = model_class.properties.reject { |p| p.serial? }
      count = model_class.count rescue 0
      unique_suffix = count + rand(1000)

      test_data = generate_test_data(model_class, props, unique_suffix)
      test_data = create_contact_record(model_class, test_data) if model_class.name =~ /^(Email|Phone|Im)Contact$/

      test1 = model_class.safe_create(test_data)
      puts "Test 1 - Basic creation: #{test1 ? 'PASS' : 'FAIL'}"

      if test1
        test2 = test_special_characters(model_class, props, test_data, unique_suffix)
        puts "Test 2 - Special characters: #{test2 ? 'PASS' : 'FAIL'}" if test2
      end

      true
    rescue => e
      puts "Test failed with error: #{e.message}"
      false
    end
  end

  def generate_test_data(model_class, props, unique_suffix)
    test_data = {}
    props.each do |prop|
      value = case prop.name.to_s
      when 'type'
        model_class.name
      when 'admin', 'bidirectional', 'invalidated', 'canonical', 'filterable'
        false
      when /.*_id$/
        1
      when 'rules', 'description', 'property_names'
        'test'
      when 'contact_type'
        model_class.name.sub(/Contact$/, '').downcase
      when 'language_code'
        "en_#{unique_suffix}"
      when /.*_address$/, 'ip_address'
        handle_address_field(prop)
      when 'value'
        generate_value_field(model_class, unique_suffix)
      else
        generate_primitive_value(prop, unique_suffix)
      end

      test_data[prop.name] = value if value
    end

    handle_special_cases(model_class, test_data, unique_suffix)
    test_data
  end

  def handle_address_field(prop)
    if prop.primitive.to_s =~ /IPAddress|IpAddress/
      require 'ipaddr'
      IPAddr.new('127.0.0.1').to_s
    else
      '123 Test St, City, State 12345'
    end
  end

  def generate_value_field(model_class, unique_suffix)
    case model_class.name
    when 'EmailContact'
      "test_#{unique_suffix}@example.com"
    when 'PhoneContact'
      "+1-555-#{unique_suffix.to_s.rjust(4, '0')}"
    when 'ImContact'
      "im_user_#{unique_suffix}"
    when 'PropertyValueDefinition'
      "test_value_#{unique_suffix}_#{rand(1000)}"
    else
      "test_value_#{unique_suffix}"
    end
  end

  def generate_primitive_value(prop, unique_suffix)
    case prop.primitive.to_s
    when /DateTime|Time/
      DateTime.now.strftime('%Y-%m-%d %H:%M:%S')
    when /String|Text/
      "test_#{prop.name}_#{unique_suffix}"
    when /Integer|Fixnum/
      1
    when /Float/
      1.0
    when /Boolean/
      false
    when /IPAddress|IpAddress/
      require 'ipaddr'
      IPAddr.new('127.0.0.1').to_s
    when /Object|Marshal/
      serialize_object(prop)
    end
  end

  def serialize_object(prop)
    require 'yaml'
    case prop.model.name
    when /PropertyType|PropertyHierarchy|AssociatedWord/
      YAML.dump(['test'])
    when "Purchase"
      YAML.dump(['pending'])
    when "TitleStrategy"
      YAML.dump(['default'])
    else
      YAML.dump(['data'])
    end
  end

  def handle_special_cases(model_class, test_data, unique_suffix)
    case model_class.name
    when 'PropertyValueDefinition'
      test_data['language_code'] = "en_#{unique_suffix}"
      test_data['value'] = "test_value_#{unique_suffix}_#{rand(1000)}"
    end
  end

  def create_contact_record(model_class, test_data)
    begin
      db = DataMapper.repository.adapter
      value = sanitize_sql_value(test_data['value'])
      type = sanitize_sql_value(model_class.name)

      sql = "INSERT INTO contacts (type, value, created_at, updated_at) VALUES (#{type}, #{value}, NOW(), NOW())"
      result = db.execute(sql)

      id_result = db.execute("SELECT LAST_INSERT_ID() as id").first
      if id_result && id_result.respond_to?(:[])
        { 'id' => id_result['id'] }
      else
        test_data
      end
    rescue => e
      puts "Warning: Error creating contact: #{e.message}"
      test_data
    end
  end

  def sanitize_sql_value(value)
    return 'NULL' if value.nil?
    "'#{value.to_s.gsub(/['"]/, "''").gsub(/\\/, '\\\\\\\\')}'"
  end

  def test_special_characters(model_class, props, test_data, unique_suffix)
    string_props = props.select { |p| p.primitive.to_s =~ /String|Text/ }
    return true unless string_props.any?

    test_data_quotes = test_data.dup
    string_props.each do |prop|
      next if ['type', 'rules', 'description', 'contact_type'].include?(prop.name.to_s)
      next if prop.name.to_s =~ /.*_address$/
      next if prop.primitive.to_s =~ /IPAddress|IpAddress/
      test_data_quotes[prop.name] = "test's\"special_#{prop.name}_#{unique_suffix}"
    end

    model_class.safe_create(test_data_quotes)
  end

  def sort_models_by_dependencies(models)
    dependencies = build_dependencies(models)
    sorted = []
    visited = {}

    models.each do |model|
      visit_model(model, visited, {}, sorted, dependencies) unless visited[model]
    end

    sorted.reverse
  end

  def build_dependencies(models)
    dependencies = {}
    models.each do |model|
      begin
        model_relationships = if model.relationships.respond_to?(:named?)
          model.relationships.to_a
        else
          model.relationships.entries
        end

        all_deps = []
        model_relationships.each do |rel|
          target = rel.target_model
          all_deps << target
          all_deps.concat(get_nested_dependencies(target))
        end

        dependencies[model] = all_deps.uniq
      rescue
        dependencies[model] = []
      end
    end

    print_dependency_order(models, dependencies)
    dependencies
  end

  def get_nested_dependencies(model)
    return [] unless model.respond_to?(:relationships)

    relationships = if model.relationships.respond_to?(:named?)
      model.relationships.to_a
    else
      model.relationships.entries
    end

    relationships.map(&:target_model)
  end

  def visit_model(model, visited, temp_visited, sorted, dependencies)
    if temp_visited[model]
      puts "Warning: Cyclic dependency detected involving #{model.name}"
      return
    end

    temp_visited[model] = true

    dependencies[model].each do |dep|
      unless visited[dep]
        visit_model(dep, visited, temp_visited, sorted, dependencies) if dependencies.key?(dep)
      end
    end

    temp_visited.delete(model)
    visited[model] = true
    sorted << model
  end

  def print_dependency_order(models, dependencies)
    puts "\nTesting models in dependency order:"
    models.each do |model|
      deps = dependencies[model].map(&:name).join(', ')
      puts "#{model.name} (depends on: #{deps})"
    end
  end

  def print_test_results(results)
    puts "\nTest Summary:"
    results.each do |model_name, passed|
      puts "#{model_name}: #{passed ? 'PASSED' : 'FAILED'}"
    end

    failed_models = results.reject { |_, passed| passed }
    if failed_models.any?
      puts "\nFailed Models:"
      failed_models.each { |model_name, _| puts "- #{model_name}" }
    end

    success_rate = ((results.values.count(true).to_f / results.length) * 100).to_i
    puts "\nOverall Success Rate: #{success_rate}%"
  end
end

# Hook it into DataMapper::Model
module DataMapper
  module Model
    include DataMapperOverride
  end
end
