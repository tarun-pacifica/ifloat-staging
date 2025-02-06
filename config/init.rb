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

# First define the module as before
module DataMapperOverride
  def self.included(base)
    base.extend(ClassMethods)
    base.class_eval do
      class << self
        alias_method :old_create, :create
        alias_method :create, :safe_create
      end
    end
  end

  module ClassMethods
    private

    def escape_value(value)
      case value
      when String
        repository(:default).adapter.send(:quote_string, value)
      else
        value
      end
    end

    def format_value(value)
      case value
      when DateTime, Time
        "'#{value.strftime('%Y-%m-%d %H:%M:%S')}'"
      when String
        "'#{escape_value(value)}'"
      when NilClass
        'NULL'
      when TrueClass
        '1'
      when FalseClass
        '0'
      else
        value.to_s
      end
    end

    public

    def safe_create(attributes = {})
      begin
        Merb.logger.info("#{self.name}#safe_create started with attributes: #{attributes.inspect}")

        repository(:default).adapter.transaction do |txn|
          begin
            table_name = self.storage_names[:default]
            columns = []
            values = []

            valid_attributes = attributes.select { |key, _| properties.map(&:name).include?(key) }

            valid_attributes.each do |key, value|
              columns << key.to_s
              values << format_value(value)
            end

            sql = "INSERT INTO #{table_name} (#{columns.join(', ')}) VALUES (#{values.join(', ')})"
            Merb.logger.debug("#{self.name}#safe_create SQL: #{sql}")

            result = repository(:default).adapter.execute(sql)
            insert_id = repository(:default).adapter.select("SELECT LAST_INSERT_ID()").first

            get(insert_id)
          rescue => e
            Merb.logger.error("#{self.name}#safe_create failed: #{e.message}\n#{e.backtrace.join("\n")}")
            txn.rollback
            raise e
          end
        end
      rescue => e
        Merb.logger.error("#{self.name}#safe_create transaction failed: #{e.message}")
        raise e
      end
    end
  end
end

# Then hook it into DataMapper::Model which all DM models include
module DataMapper
  module Model
    include DataMapperOverride
  end
end
