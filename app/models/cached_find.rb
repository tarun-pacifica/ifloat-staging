# = Summary
#
# A CachedFind is created every time a 'find' is initiated by supplying a multi-word specification. Indeed a CachedFind may be thought of as the combination of a valid specification (in a given language) and a marshalled set of filters differentiating the 'found' products.
#
# CachedFinds may optionally belong to a User. Those that do not are considered 'anonymous' and in turn are treated as 'archived' upon obsolescence. To assist users in organising their CachedFinds, a description may be added.
#
# CachedFind operations (and filter value caching) are based on the Indexer and thus every time the global catalogue is updated (at product import time), all CachedFinds are marked as 'invalidated' and reset when they are next accessed.
#
# = Processes
#
# === 1. Anonimize Unused CachedFinds
#
# Run CachedFind.unusued.update!(:user_id => nil) periodically. This will detach any unused CachedFinds from their parent users.
#
# === 2. Destroy Obsolete CachedFinds
#
# Run CachedFind.obsolete.destroy! peridically. This will destroy any anonymous CachedFinds no longer featured in any Session.
#
class CachedFind
  include DataMapper::Resource
  
  ANONIMIZATION_TIME = 1.month
  
  property :id, Serial
  property :language_code, String, :required => true, :format => /^[A-Z]{3}$/
  property :specification, String, :length => 255
  property :description, String, :length => 255
  property :filters, Object, :writer => :protected, :lazy => false
  property :accessed_at, DateTime
  property :invalidated, Boolean, :default => true
  
  belongs_to :user, :required => false
  
  validates_with_block :language_code, :unless => :new? do
    attribute_dirty?(:language_code) ? [false, "cannot be updated"] : true
  end
  
  validates_with_block :specification, :unless => :new? do
    attribute_dirty?(:specification) ? [false, "cannot be updated"] : true
  end
  
  validates_with_block :specification do
    words = specification.split
    if words.empty? or words.any? { |word| word.size < 3 }
      [false, "should be one or more words, each at least 3 characters long"]
    else true
    end
  end
  
  before :valid? do
    self.specification = (specification || "").split.uniq.join(" ")
    self.description = specification if description.blank?
  end
  
  def self.obsolete
    all(:user_id => nil, :accessed_at.lt => Merb::Config[:session_ttl].ago)
  end
  
  def self.unused
    all(:user_id.not => nil, :accessed_at.lt => ANONIMIZATION_TIME.ago)
  end
  
  def all_product_count
    all_product_ids.size
  end
  
  def all_product_ids
    @all_product_ids ||= Indexer.product_ids_for_phrase(specification, language_code)
  end
  
  def ensure_valid
    invalidated? ? execute! : nil
  end
  
  def execute!
    raise "cannot execute invalid CachedFind" unless valid?
    
    text_property_ids = Indexer.filterable_text_property_ids_for_product_ids(all_product_ids, language_code)
    numeric_limits_by_property_id = Indexer.numeric_limits_for_product_ids(all_product_ids)
    
    properties = PropertyDefinition.all(:id => text_property_ids + numeric_limits_by_property_id.keys)
    PropertyType.all(:id => properties.map { |p| p.property_type_id }).map
    friendly_names = PropertyDefinition.friendly_name_sections(properties, language_code)
    
    # TODO: copy old values where possible
    filters = []
    properties.each do |property|
      filter = {
        :prop_id            => property.id,
        :prop_seq_num       => property.sequence_number,
        :prop_friendly_name => friendly_names[property.id],
        :prop_type          => property.property_type.core_type,
        :include_unknown    => true,
        :data               => []
      }
      
      if ["currency", "date", "numeric"].include?(filter[:prop_type])
        limits = numeric_limits_by_property_id[property.id]
        filter[:data] += numeric_filter_choose(nil, nil, nil, limits)
        filter[:data] << limits
      end
      
      filters << filter
    end
    self.filters = filters.sort_by { |filter| filter[:prop_seq_num] }
    filters.each { |filter| filter.delete(:prop_seq_num) }
    
    self.invalidated = false
    save
  end
  
  # TODO: spec
  def filter!(property_id, operation, params)
    filters = Marshal.load(Marshal.dump(self.filters))
    filter = filters.find { |filter| filter[:prop_id] == property_id }
    return if filter.nil?
    
    if operation == "include_unknown"
      filter[:include_unknown] = (params["value"] == "true")
      self.filters = filters
      save
      return
    end
    
    data = filter[:data]
    
    case filter[:prop_type]
    when "currency", "date", "numeric"
      min, max = params.values_at("min", "max").map { |v| v.to_f }
      unit = params["unit"]
      unit = nil if unit.blank?
      filter[:data][0..2] = numeric_filter_choose(min, max, unit, data.last)
    when "text"
      value = params["value"]
      p [operation, value, data]
      case operation
      when "exclude"
        p data.include?(value)
        p text_filter_words(property_id).include?(value)
        data << value unless data.include?(value) or not text_filter_words(property_id).include?(value)
      when "include"
        data.delete(value)
      when "include_only"
        data.replace(text_filter_words(property_id))
        data.delete(value)
      end
    end
    
    self.filters = filters
    save
  end
  
  def filter_values
    fpids = filtered_product_ids(true)
    text_values = Indexer.filterable_text_values_for_product_ids(all_product_ids, fpids, language_code)
    numeric_limits = Indexer.numeric_limits_for_product_ids(fpids)
    [text_values, numeric_limits]
  end
  
  # TODO: spec
  def filter_values_relevant(text_values_by_property_id, numeric_limits_by_property_id)
    relevant_values_by_property_id = {}
    
    filters.each do |filter|
      property_id, type = filter.values_at(:prop_id, :prop_type)
      relevant_values = (type == "text" ? text_values_by_property_id[property_id].last : nil)
      
      if filter_fresh?(filter)
        case type
        when "currency", "date", "numeric" then next unless numeric_limits_by_property_id.has_key?(property_id)
        when "text" then next if relevant_values.empty?
        end
      end
      
      relevant_values_by_property_id[property_id] = relevant_values
    end
    
    relevant_values_by_property_id
  end
  
  # TODO: spec for class_only filtering
  def filtered_product_ids(class_only = false)
    return [] if all_product_count.zero?
    
    used_filters = filters.select { |filter| not filter_fresh?(filter) }
    used_filters = used_filters.select { |filter| filter[:prop_id] == Indexer.class_property_id } if class_only
    return all_product_ids if used_filters.empty?
    
    # TODO: spec examples where this kicks in
    relevant_product_ids = all_product_ids
    focussed_property_ids = used_filters.reject { |filter| filter[:include_unknown] }.map { |filter| filter[:prop_id] }
    relevant_product_ids &= Indexer.product_ids_for_filterable_property_ids(focussed_property_ids, language_code) unless focussed_property_ids.empty?
    
    text_filters, numeric_filters = used_filters.partition { |filter| filter[:prop_type] == "text" }
    excluded_product_ids = Indexer.excluded_product_ids_for_numeric_filters(numeric_filters)
    excluded_product_ids += Indexer.excluded_product_ids_for_text_filters(text_filters, language_code)
    relevant_product_ids - excluded_product_ids
  end
  
  # TODO: spec
  def filtered_product_ids_by_image_checksum
    Indexer.image_checksums_for_product_ids(filtered_product_ids)
  end
  
  def spec_date
    if accessed_at.nil? then specification
    else "#{specification} (#{accessed_at.strftime('%Y/%m/%d %H:%M:%S')})"
    end
  end
  
  
  private
  
  def filter_fresh?(filter)
    filter[:include_unknown] and
    case filter[:prop_type]
    when "currency", "date", "numeric"
      min, max, unit, limits = filter[:data]
      [min, max, unit] == numeric_filter_choose(nil, nil, unit, limits)
    when "text"
      filter[:data].empty?
    end
  end
  
  def numeric_filter_choose(min, max, unit, limits)
    unless limits.has_key?(unit)
      unit = limits.keys.sort_by { |unit| unit.to_s }.first
      min, max = nil, nil
    end
    
    min_limit, max_limit = limits[unit]
    
    min = min_limit if min.nil?
    max = max_limit if max.nil?    
    min, max = [min, max].map { |m| [[m, min_limit].max, max_limit].min }.sort
    
    [min, max, unit]
  end
  
  def text_filter_words(property_id)
    words_by_property_id = Indexer.filterable_text_values_for_product_ids(all_product_ids, [], language_code, property_id)
    words_by_property_id[property_id].first
  end
end
