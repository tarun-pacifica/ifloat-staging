# = Summary
#
# A CachedFind is created every time a 'find' is initiated by supplying a multi-word specification. Indeed a CachedFind may be thought of as the combination of a valid specification (in a given language) and a set of filterable PropertyValues broken out into CachedFindFilter objects.
#
# CachedFinds may optionally belong to a User. Those that do not are considered 'anonymous' and in turn are treated as 'archived' upon obsolescence. To assist users in organising their CachedFinds, a description may be added.
#
# The act of executing the CachedFind takes a snapshot of all the pertinent values as well as every DefinitiveProduct included by an initial search of the database. Thus CachedFinds (for performance and user-consistency reasons) get progressively out-of-date with respect to the live DefinitiveProduct / PropertyValue information. For this reason, calls to CachedFind#products or CachedFind#total_product_count will trigger (re-)execution automatically if the CachedFind has either never been run or was run more than OBSOLESCENCE_TIME ago. TODO: revise
#
# In deference to both the existence of untranslatable values (such as brand names) and the fact that translation takes time, the lookup mechanism searches in both the requested language and English (ENG). When a value set is returned for a particular PropertyDefinition, if *no* value exists in the chosen (non-English) language, then the English values will be used instead. If one or more non-English values do exist, the English values will be discarded.
#
# For future-proofing, Assets may be attached to a CachedFind. It is envisaged that this will allow Users (or the application itself) to assign images etc... to searches. This feature is currently speculative.
#
# = Processes
#
# === 1. Archived Unused CachedFinds
#
# Run CachedFind.anonimize_unused periodically. This will detach any unused CachedFinds from their parent users. Note that, although a process exists to destroy archived Filters, no such process exists for CachedFinds as a record of all specifications has been deemed to be essential data for the future.
#
class CachedFind
  include DataMapper::Resource
  
  ANONIMIZATION_TIME = 1.month
  
  property :id, Serial
  property :language_code, String, :nullable => false, :format => /^[A-Z]{3}$/
  property :specification, String, :size => 255
  property :description, String, :size => 255
  property :filters, Object, :writer => :protected, :lazy => false
  property :accessed_at, DateTime
  property :invalidated, Boolean, :default => true
  
  belongs_to :user
  has n, :attachments
  
  # TODO: spec
  validates_with_block :language_code, :unless => :new_record? do
    attribute_dirty?(:language_code) ? [false, "cannot be updated"] : true
  end
  
  # TODO: spec
  validates_with_block :specification, :unless => :new_record? do
    attribute_dirty?(:specification) ? [false, "cannot be updated"] : true
  end
  
  validates_with_block :specification do
    words = specification.split
    if words.empty? or words.any? { |word| word.size < 3 }
      [false, "should be one or more words, each at least 3 characters long"]
    else true
    end
  end
  
  before :destroy do
    attachments.destroy!
  end
  
  before :valid? do
    self.specification = (specification || "").split.uniq.join(" ")
    self.description = specification if description.blank?
  end
  
  def self.anonimize_unused
    all(:accessed_at.lt => ANONIMIZATION_TIME.ago).update!(:user_id => nil)
  end
  
  def self.archived
    obsolete.all(:user_id => nil)
  end
  
  def self.obsolete
    all(:accessed_at.lt => OBSOLESCENCE_TIME.ago)
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
    
    self.invalidated = false
    save
  end
  
  # TODO: spec
  def filter!(property_id, operation, params)
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
      case operation
      when "exclude"
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
  
  # TODO: spec
  def filter_values
    fpids = filtered_product_ids(true)
    text_values_by_property_id = Indexer.filterable_text_values_for_product_ids(all_product_ids, fpids, language_code)
    numeric_limits_by_property_id = Indexer.numeric_limits_for_product_ids(fpids)
    
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
    
    [text_values_by_property_id, relevant_values_by_property_id]
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
  def filtered_product_ids_by_image_url
    Indexer.image_urls_for_product_ids(filtered_product_ids)
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
