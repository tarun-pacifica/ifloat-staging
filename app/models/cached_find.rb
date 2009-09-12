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
  property :accessed_at, DateTime
  property :invalidated, Boolean, :default => true
  
  belongs_to :user
  has n, :attachments
  has n, :filters
  
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
    filters.each { |filter| filter.destroy }
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
    raise "cannot execute unsaved CachedFind" if new_record?
    
    existing_filters = NumericFilter.all(:cached_find_id => id).hash_by(:property_definition_id)
    existing_filters.update(TextFilter.all(:cached_find_id => id).hash_by(:property_definition_id))
    
    to_save = []
    new_property_ids = []
    
    Indexer.filterable_text_property_ids_for_product_ids(all_product_ids, language_code).each do |property_id|
      new_property_ids << property_id      
      filter = existing_filters[property_id]
      to_save << TextFilter.new(:cached_find_id => id, :property_definition_id => property_id) if filter.nil?
    end
    
    Indexer.numeric_limits_for_product_ids(all_product_ids).each do |property_id, limits_by_unit|
      new_property_ids << property_id      
      filter = existing_filters[property_id]
      filter = NumericFilter.new(:cached_find_id => id, :property_definition_id => property_id) if filter.nil?
      filter.limits = limits_by_unit
      to_save << filter if filter.dirty?
    end
    
    # TODO: spec this functionality
    existing_filters.each { |property_id, filter| filter.destroy unless new_property_ids.include?(property_id) }
    to_save.each { |filter| filter.save }
    
    self.invalidated = false
    save
  end
  
  # TODO: spec
  def filter_values(lookup_exclusions = true)
    filters_by_property_id = filters.hash_by(:property_definition_id)
    
    text_values_by_fid = {}
    fpids = filtered_product_ids
    Indexer.filterable_text_values_for_product_ids(all_product_ids, fpids, language_code).each do |property_id, all_relevant|
      filter_id = filters_by_property_id[property_id].id
      text_values_by_fid[filter_id] = (all_relevant << [])
    end
    
    if lookup_exclusions
      filter_ids = filters.map { |filter| filter.id }
      TextFilterExclusion.all(:text_filter_id => filter_ids).each do |exclusion|
        text_values_by_fid[exclusion.text_filter_id].last << exclusion.value
      end
    end
    
    numeric_limits_by_property_id = Indexer.numeric_limits_for_product_ids(fpids) 
    relevant_values_by_fid = {}
    filters.each do |filter|
      relevant_values = nil
      if filter.text?
        relevant_values = text_values_by_fid[filter.id][1]
        next if filter.fresh? and relevant_values.empty?
      else
        next if filter.fresh? and not numeric_limits_by_property_id.has_key?(filter.property_definition_id)
      end

      relevant_values_by_fid[filter.id] = relevant_values
    end
    
    [text_values_by_fid, relevant_values_by_fid]
  end
  
  def filtered_product_ids
    return [] if all_product_count.zero?
    
    used_filters = filters.select { |filter| not filter.fresh? }
    return all_product_ids if used_filters.empty?
    
    # TODO: spec examples where this kicks in
    used_filter_pdids = used_filters.map { |filter| filter.property_definition_id }
    relevant_product_ids = (all_product_ids & Indexer.product_ids_for_filterable_property_ids(used_filter_pdids, language_code))
    
    text_filters, numeric_filters = used_filters.partition { |filter| filter.text? }
    excluded_product_ids = Indexer.excluded_product_ids_for_numeric_filters(numeric_filters)
    excluded_product_ids += Indexer.excluded_product_ids_for_text_filters(text_filters, language_code)
    relevant_product_ids - excluded_product_ids
  end
  
  # TODO: spec
  def reset
    filters.all.each { |filter| filter.destroy }
    execute!
  end
  
  def spec_date
    if accessed_at.nil? then specification
    else "#{specification} (#{accessed_at.strftime('%Y/%m/%d %H:%M:%S')})"
    end
  end
end
