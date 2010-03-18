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
    self.filters ||= {}
  end
  
  def self.obsolete
    all(:user_id => nil, :accessed_at.lt => Merb::Config[:session_ttl].ago)
  end
  
  def self.unused
    all(:user_id.not => nil, :accessed_at.lt => ANONIMIZATION_TIME.ago)
  end
  
  def all_product_ids
    @all_product_ids ||= Indexer.product_ids_for_phrase(specification, language_code)
  end
  
  # TODO: spec
  def ensure_valid
    return [] unless invalidated?
    
    changes = [] # TODO: track changes
    new_filters = {}
    pdc = Indexer.property_display_cache
    
    filters.each do |property_id, filter|
      prop_info = pdc[property_id]
      next if prop_info.nil?
      
      type = prop_info[:type]
      choices, unit =
        if type == "text" then [filter[:data], language_code]
        else [filter[:data][0..1], filter[:data][2]]
        end
      data = filter_sanitize_choice(property_id, type, choices, unit)
      next if data.nil?
      
      new_filters[property_id] = {:data => data, :include_unknown => filter[:include_unknown]} unless data.nil?
    end
    
    self.invalidated = false
    self.filters = new_filters
    save ? changes : []
  end
  
  # TODO: spec
  def filter_detail(property_id)
    prop_info = Indexer.property_display_cache[property_id]
    return nil if prop_info.nil?
    
    definitions = (PropertyValueDefinition.by_property_id([property_id], language_code)[property_id] || {})
    filter = (filters[property_id] || {:include_unknown => (property_id == Indexer.class_property_id ? nil : false)})
    type = prop_info[:type]
    value_class = PropertyType.value_class(type)
    
    apids, fpids = all_product_ids, filtered_product_ids
    values_by_unit = {}
    Indexer.filterable_values_for_property_id(property_id, apids, fpids, language_code).each do |unit, values|
      all_values, relevant_values = values
      relevant = Set.new(relevant_values)
      
      selected_values = 
        if filter[:data].nil? then all_values
        elsif type == "text" then filter[:data]
        else
          min, max, filter_unit = filter[:data]
          if filter_unit != unit then all_values
          else all_values.select { |v| min <= v && max >= v }
          end
        end
      selected = Set.new(selected_values)
        
      extra_values =
        if type == "text" then all_values.map { |v| definitions[v] }
        else all_values.map { |v| value_class.format(v, v, nil, unit, :verbose => true) }
        end
      
      values_by_unit[unit] = all_values.each_with_index.map do |v, i|
        [v, selected.include?(v), relevant.include?(v), extra_values[i]]
      end
    end
    
    prop_info.merge(:include_unknown => filter[:include_unknown], :values_by_unit => values_by_unit)
  end
  
  # TODO: spec
  def filter!(property_id, params)
    prop_info = Indexer.property_display_cache[property_id]
    return nil if prop_info.nil?
    return nil unless filters.has_key?(property_id) or property_ids_unused.include?(property_id)
    
    type = prop_info[:type]
    unit = (params["unit"].blank? ? nil : params["unit"])
    data = filter_sanitize_choice(property_id, type, params["value"].split("::"), unit)
    return nil if data.nil?
    
    new_filters = Marshal.load(Marshal.dump(filters))
    filter = (new_filters[property_id] ||= {})
    filter[:data] = data
    filter[:include_unknown] = (property_id == Indexer.class_property_id ? nil : params["include_unknown"] == "true")
    self.filters = new_filters
    save
  end
  
  def filtered_product_ids
    return [] if all_product_ids.empty?
    
    property_ids = filters.keys
    return all_product_ids if property_ids.empty?
    
    # TODO: spec examples where this kicks in
    # - the idea is that all products are relevant by default
    # - since we use exclusion based filtering, any product without a value will not be excluded normally
    # - thus if we mark a filter as not including unknown, we specifically limit the products to the set with that filter's property_id
    relevant_product_ids = all_product_ids
    required_property_ids = property_ids.select { |id| filters[id][:include_unknown] == false }
    relevant_product_ids &= Indexer.product_ids_for_property_ids(required_property_ids, language_code) unless required_property_ids.empty?
    relevant_product_ids - Indexer.excluded_product_ids_for_filters(filters, language_code)
  end
  
  # TODO: spec
  def filtered_product_ids_by_image_checksum
    Indexer.image_checksums_for_product_ids(filtered_product_ids)
  end
  
  # TODO: spec
  def filters_unused
    Indexer.property_display_cache.values_at(*property_ids_unused).compact.sort_by { |info| info[:seq_num] }
  end
  
  # TODO: spec
  def filters_used(range_sep)
    infos = Indexer.property_display_cache.values_at(*(filters.keys)).compact.sort_by { |info| info[:seq_num] }
    infos.map do |info|
      filter = filters[info[:id]]
      info.merge(:summary=> filter_summarize(info[:type], filter[:data], range_sep))
    end
  end
  
  # TODO: spec
  def unfilter!(property_id)
    return nil unless filters.has_key?(property_id)
    new_filters = Marshal.load(Marshal.dump(filters))
    new_filters.delete(property_id)
    self.filters = new_filters
    save
  end
  
  # TODO: spec
  def unfilter_all!
    self.filters = {}
    save
  end
  
  
  private
  
  def filter_sanitize_choice(property_id, type, choices, unit)
    values_by_unit = Indexer.filterable_values_for_property_id(property_id, all_product_ids, [], language_code)
    return nil if values_by_unit.nil?
    
    unit = values_by_unit.keys.sort_by { |unit| unit.to_s }.first unless values_by_unit.has_key?(unit)
    all_values, relevant_values = values_by_unit[unit]
    
    return choices.nil? ? all_values : (choices & all_values) if type == "text"
      
    min_limit, max_limit = all_values.first, all_values.last
    (choices || [min_limit, max_limit]).map { |m| [[m.to_f, min_limit].max, max_limit].min }.sort + [unit]
  end
    
  def filter_summarize(type, data, range_sep)
    if type == "text"
      values = data
      return values.empty? ? "[none]" : values.join(", ").truncate(40)
    end
    
    begin
      min, max, unit = data
      PropertyType.value_class(type).format(min, max, range_sep, unit)
    rescue
      "unknown type #{type.inspect}"
    end
  end
  
  def property_ids_unused
    Indexer.property_ids_for_product_ids(filtered_product_ids, language_code).reject { |id| filters.has_key?(id) }
  end
end
