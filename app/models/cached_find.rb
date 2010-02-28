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
  
  property :id,            Serial
  property :language_code, String,  :required => true, :format => /^[A-Z]{3}$/
  property :specification, String,  :length => 255
  property :description,   String,  :length => 255
  property :filters,       Object,  :accessor => :protected, :lazy => false
  property :accessed_at,   DateTime
  property :invalidated,   Boolean, :required => true, :default => true
  
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
    self.filters = {}
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
  
  # TODO: spec
  def ensure_valid
    return [] unless invalidated?
    
    changes = [] # TODO: track changes
    new_filters = {}
    numeric_limits_by_property_id = Indexer.numeric_limits_for_product_ids(all_product_ids)
    pdc = Indexer.property_display_cache
    
    filters.each do |property_id, filter|
      prop_info = pdc[property_id]
      next if prop_info.nil?
      
      data =
        case prop_info[:type]
        when "currency", "date", "numeric"
          limits = numeric_limits_by_property_id[property_id]
          next if limits.nil?
          min, max, unit = filter[:data]
          numeric_filter_choose(min, max, unit, limits)
        when "text"
          values = text_filter_values
          next if values.nil?
          filter[:data] & values
        end
      
      new_filters[property_id] = {:data => data, :include_unknown => filter[:include_unknown]}
    end
    
    self.invalidated = false
    self.filters = new_filters
    save ? changes : []
  end
  
  # TODO: spec
  def filter!(property_id, params)
    prop_info = Indexer.property_display_cache[property_id]
    return if property.nil?
    return unless filters.has_key?(property_id) or property_ids_unused.include?(property_id)
    
    new_filters = Marshal.load(Marshal.dump(self.filters))
    filter = (new_filters[property_id] || {})
    new_filters[property_id] = filter if filter.empty?
    
    filter[:include_unknown] = (property_id == Indexer.class_property_id ? false : params["include_unknown"] == "true")
    
    case prop_info[:type]
    when "currency", "date", "numeric"
      limits = Indexer.numeric_limits_for_product_ids(all_product_ids, property_id)[property_id]
      return if limits.nil?
      min, max = params.values_at("min", "max").map { |v| v.to_f }
      unit = params["unit"]; unit = nil if unit.blank?
      filter[:data] = numeric_filter_choose(min, max, unit, limits)
    when "text"
      values = text_filter_values(property_id)
      return if values.nil?
      filter[:data].replace(params["count"].to_i.times.map { |i| params["value_#{i}"] } & values)
    end
    
    self.filters = filters
    save
  end
    
  # TODO: spec
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
      property_id, type = filter.values_at(:id, :type)
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
    
    property_ids = filters.keys
    property_ids &= [Indexer.class_property_id] if class_only    
    return all_product_ids if property_ids.empty?
    
    # TODO: spec examples where this kicks in
    # - the idea is that all products are relevant by default
    # - since we use exclusion based filtering, any product without a value will not be excluded normally
    # - thus if we mark a filter as not including unknown, we specifically limit the products to the set with that filter's property_id
    relevant_product_ids = all_product_ids
    focussed_property_ids = property_ids.reject { |id| filters[id][:include_unknown] }
    relevant_product_ids &= Indexer.product_ids_for_filterable_property_ids(focussed_property_ids, language_code) unless focussed_property_ids.empty?
    
    numeric_filters, text_filters = {}, {}
    pdc = Indexer.property_display_cache
    property_ids.each do |property_id|
      prop_info = pdc[property_id]
      next if prop_info.nil?
      (prop_info[:type] == "text" ? text_filters : numeric_filters)[property_id] = filters[property_id][:data]
    end
    
    excluded_product_ids = Indexer.excluded_product_ids_for_numeric_filters(numeric_filters)
    excluded_product_ids += Indexer.excluded_product_ids_for_text_filters(text_filters, language_code)
    relevant_product_ids - excluded_product_ids
  end
  
  # TODO: spec
  def filtered_product_ids_by_image_checksum
    Indexer.image_checksums_for_product_ids(filtered_product_ids)
  end
  
  # TODO: spec
  def filters_unused
    Indexer.property_display_cache.values_at(*property_ids_unused).sort_by { |info| info[:seq_num] }
  end
  
  # TODO: spec
  def filters_used(range_sep)
    filters.values.sort_by! { |filter| filter[:seq_num] }.map do |filter|
      section, name = filter[:friendly_name]
      summary = filter_summarize(filter, range_sep)
      {:section => section, :name => name, :icon_url => filter[:icon_url], :summary => summary}
    end
  end
  
  # TODO: spec
  def spec_count
    "#{specification} (#{filtered_product_ids.size} / #{all_product_count})"
  end
  
  # TODO: spec
  def unfilter!(property_id)
    return unless filters.has_key?(property_id)
    self.filters = Marshal.load(Marshal.dump(self.filters)).delete(property_id)
    save
  end
  
  
  private
    
  def filter_summarize(filter, range_sep)
    type = filter[:type]
    
    if type == "text"
      values = filter[:data]
      return values.empty? ? "[none]" : values.sort.join(", ").truncate(50)
    end
    
    begin
      min, max, unit, limits = filter[:data]
      PropertyType.value_class(type).format(min, max, range_sep, unit)
    rescue
      "unknown type #{type.inspect}"
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
  
  def property_ids_unused
    text_property_ids = Indexer.filterable_text_property_ids_for_product_ids(all_product_ids, language_code)
    numeric_limits_by_property_id = Indexer.numeric_limits_for_product_ids(all_product_ids)
    (text_property_ids + numeric_limits_by_property_id.keys).reject { |id| filters.has_key?(id) }
  end
  
  def text_filter_values(property_id)
    words_by_prop_id = Indexer.filterable_text_values_for_product_ids(all_product_ids, [], language_code, property_id)
    all_values, relevant_values = words_by_prop_id[property_id]
    all_values
  end
end
