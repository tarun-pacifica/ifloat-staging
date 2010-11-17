# = Summary
#
# A CachedFind is created every time a 'find' is initiated by supplying a multi-word specification. Indeed a CachedFind may be thought of as the combination of a valid specification (in a given language) and a marshalled set of filters differentiating the 'found' products.
#
# CachedFinds may optionally belong to a User. Those that do not are considered 'anonymous' and in turn are treated as 'archived' upon obsolescence. To assist users in organising their CachedFinds, a description may be added.
#
# CachedFind operations (and filter value caching) are based on the Indexer and thus every time the global catalogue is updated (at product import time), all CachedFinds are marked as 'invalidated' and reset when they are next accessed.
#
# A specification surrounded by '{...}' is taken as a literal tag match. This custom syntax is needed to support the one filtering-style use case where we do not want to mark the relevant properties as filterable.
#
# = Processes
#
# === 1. Anonimize Unused CachedFinds
#
# Run CachedFind.unused.update!(:user_id => nil) periodically. This will detach any unused (accessed more then ANONIMIZATION_TIME ago) CachedFinds from their parent users.
#
# === 2. Destroy Obsolete CachedFinds
#
# When destroying sessions, destroy any anonymous cached finds whose IDs no longer appear in any session.
#
class CachedFind
  include DataMapper::Resource
  
  ANONIMIZATION_TIME = 1.month
  
  property :id,            Serial
  property :language_code, String,  :required => true, :format => /^[A-Z]{3}$/
  property :specification, String,  :required => true, :length => 255
  property :description,   String,  :length => 255
  property :filters,       Object,  :accessor => :protected, :lazy => false
  property :accessed_at,   DateTime
  property :invalidated,   Boolean, :required => true, :default => false
  
  belongs_to :user, :required => false
  
  validates_with_block :language_code, :unless => :new? do
    attribute_dirty?(:language_code) ? [false, "Language code cannot be updated"] : true
  end
  
  validates_with_block :specification, :unless => :new? do
    attribute_dirty?(:specification) ? [false, "Specification cannot be updated"] : true
  end
  
  before :valid? do
    self.specification = (specification || "").split.uniq.join(" ") if new? and not tag_find?
    self.description = specification if description.blank?
    self.filters ||= {}
  end
  
  def self.unused
    all(:user_id.not => nil, :accessed_at.lt => ANONIMIZATION_TIME.ago)
  end
  
  def all_product_ids
    @all_product_ids ||=
      if tag_find? then Indexer.product_ids_for_tag(specification[1..-2], language_code)
      else Indexer.product_ids_for_phrase(specification, language_code)
      end
  end
  
  # TODO: spec
  def alternative_specs
    return [] if tag_find?
    
    words = specification.split.map { |word| Indexer.correct_spelling(word, language_code) }.compact
    return words if words.size <= 1
    
    (words.size - 1).downto(1) do |i|
      hits = words.combination(i).map do |combo|
        spec = combo.join(" ")
        (Indexer.product_ids_for_phrase(spec, language_code).size > 0) ? spec : nil
      end.compact
      return hits unless hits.empty?
    end
    
    []
  end
  
  def ensure_valid
    return [] unless invalidated?
    
    changes = []
    new_filters = {}
    pdc = Indexer.property_display_cache
    
    filters.each do |property_id, filter|
      prop_info = pdc[property_id]
      if prop_info.nil?
        changes << "Discarded filter for defunct property #{property_id}"
        next
      end
      
      type = prop_info[:type]
      choices, unit =
        if type == "text" then [filter[:data], language_code]
        else [filter[:data][0..1], filter[:data][2]]
        end
      data = filter_sanitize_choice(property_id, type, choices, unit)
      if data.nil?
        changes << "Discarded filter for #{prop_info[:raw_name]} as unable to sanitize data"
        next
      end
      
      new_filters[property_id] = {:data => data, :include_unknown => filter[:include_unknown]}
      changes << "Updated filter values for #{prop_info[:raw_name]}" unless data == filter[:data]
    end
    
    self.invalidated = false
    self.filters = new_filters
    save ? changes : []
  end
  
  def filter_detail(property_id)
    prop_info = Indexer.property_display_cache[property_id]
    return nil if prop_info.nil?
    
    definitions = (PropertyValueDefinition.by_property_id([property_id], language_code)[property_id] || {})
    filter = (filters[property_id] || {:include_unknown => (property_id == Indexer.class_property_id ? nil : false)})
    type = prop_info[:type]
    value_class = PropertyType.value_class(type)
    
    apids, fpids = all_product_ids, filtered_product_ids(property_id)
    values_by_unit = {}
    Indexer.filterable_values_for_property_id(property_id, apids, fpids, language_code).each do |unit, values|
      all_values, relevant_values = values
      relevant = relevant_values.to_set
      
      selected_values = 
        if filter[:data].nil? then all_values
        elsif type == "text" then filter[:data]
        else
          min, max, filter_unit = filter[:data]
          if filter_unit != unit then all_values
          else all_values.select { |v| min <= v && max >= v }
          end
        end
      selected = selected_values.to_set
        
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
  
  def filter!(property_id, params)
    prop_info = Indexer.property_display_cache[property_id]
    return nil if prop_info.nil?
    return nil unless filters.has_key?(property_id) or property_ids_unused.include?(property_id)
    
    type = prop_info[:type]
    unit = (params["unit"].blank? ? nil : params["unit"])
    data = filter_sanitize_choice(property_id, type, (params["value"] || "").split("::"), unit)
    return nil if data.nil?
    
    new_filters = Marshal.load(Marshal.dump(filters))
    filter = (new_filters[property_id] ||= {})
    filter[:data] = data
    filter[:include_unknown] = (property_id == Indexer.class_property_id ? nil : params["include_unknown"] == "true")
    self.filters = new_filters
    save
  end
  
  def filtered_product_ids(ignore_filter_id = nil)
    return [] if all_product_ids.empty?
    
    filts = filters
    unless ignore_filter_id.nil?
      filts = filters.dup
      filts.delete(ignore_filter_id)
    end
    
    property_ids = filts.keys
    return all_product_ids if property_ids.empty?
    
    relevant_product_ids = all_product_ids
    required_property_ids = property_ids.select { |id| filts[id][:include_unknown] == false }
    relevant_product_ids &= Indexer.product_ids_for_property_ids(required_property_ids, language_code) unless required_property_ids.empty?
    relevant_product_ids - Indexer.excluded_product_ids_for_filters(filts, language_code)
  end
  
  def filtered_product_ids_by_image_checksum
    Indexer.image_checksums_for_product_ids(filtered_product_ids)
  end
  
  def filters_unused
    Indexer.property_display_cache.values_at(*property_ids_unused).compact.sort_by { |info| info[:seq_num] }
  end
  
  def filters_used(range_sep)
    infos = Indexer.property_display_cache.values_at(*(filters.keys)).compact.sort_by { |info| info[:seq_num] }
    infos.map { |info| info.merge(:summary=> filter_summarize(info, range_sep)) }
  end
  
  def unfilter!(property_id)
    return nil unless filters.has_key?(property_id)
    new_filters = Marshal.load(Marshal.dump(filters))
    new_filters.delete(property_id)
    self.filters = new_filters
    save
  end
  
  def unfilter_all!
    self.filters = {}
    save
  end
  
  # TODO: spec
  def tag_find?
    specification =~ /^\{.+?\}$/
  end
  
  
  private
  
  def filter_sanitize_choice(property_id, type, choices, unit)
    values_by_unit = Indexer.filterable_values_for_property_id(property_id, all_product_ids, [], language_code)
    return nil if values_by_unit.empty?
    
    unit = values_by_unit.keys.sort_by { |unit| unit.to_s }.first unless values_by_unit.has_key?(unit)
    all_values, relevant_values = values_by_unit[unit]
    
    return choices.nil? ? all_values : (choices & all_values) if type == "text"
      
    min_limit, max_limit = all_values.first, all_values.last
    (choices || [min_limit, max_limit]).map { |m| [[m.to_f, min_limit].max, max_limit].min }.sort + [unit]
  end
    
  def filter_summarize(info, range_sep)
    property_id, type = info.values_at(:id, :type)    
    filter = filters[property_id]
    
    if type == "text"
      apids, fpids = all_product_ids, filtered_product_ids(property_id)
      all_values, relevant_values = Indexer.filterable_values_for_property_id(property_id, apids, fpids, language_code)[language_code]
      
      values = (filter[:data] & relevant_values)
      return values.empty? ? "[none]" : values.sort.join(", ").truncate_utf8(40)
    end
    
    begin
      min, max, unit = filter[:data]
      PropertyType.value_class(type).format(min, max, range_sep, unit)
    rescue
      "unknown type #{type.inspect}"
    end
  end
  
  def property_ids_unused
    Indexer.property_ids_for_product_ids(filtered_product_ids, language_code).reject { |id| filters.has_key?(id) }
  end
end
