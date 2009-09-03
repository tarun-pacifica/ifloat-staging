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
  # TODO: consider making this a proper DB table rather than a flattened list (this isn't scaling)
  property :product_id_list, Text, :lazy => false
  property :executed_at, DateTime
  
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
    all(:executed_at.lt => ANONIMIZATION_TIME.ago).update!(:user_id => nil)
  end
  
  def self.archived
    obsolete.all(:user_id => nil)
  end
  
  def self.obsolete
    all(:executed_at.lt => OBSOLESCENCE_TIME.ago)
  end
  
  def all_product_count
    all_product_ids.size
  end
  
  def all_product_ids
    product_id_list.to_s.split(",").map { |product_id| product_id.to_i }
  end
  
  def ensure_executed
    should_execute = executed_at.nil?
    unless should_execute
      last_import_run = ImportEvent.first(:succeeded => true, :order => [:completed_at.desc])
      should_execute = (last_import_run.completed_at >= executed_at) unless last_import_run.nil?
    end
    execute! if should_execute
    should_execute
  end

  def execute!
    raise "cannot execute invalid CachedFind" unless valid?
    raise "cannot execute unsaved CachedFind" if new_record?
    
    languages = [language_code, "ENG"]
    
    product_ids = TextPropertyValue.product_ids_matching_spec(specification, languages)
    if product_ids.empty?
      filters.each { |filter| filter.destroy }
      self.product_id_list = ""
      self.filters = []
      self.executed_at = Time.now
      return save
    end
    self.product_id_list = product_ids.join(",")
    
    existing_filters = {}
    filters.each do |filter|
      existing_filters[filter.property_definition_id] = filter
    end
    
    new_filters = []
    new_property_ids = []
    filterable_property_ids = PropertyDefinition.all(:filterable => true).map { |property| property.id }
    
    preferred_languages = TextPropertyValue.preferred_languages(filterable_property_ids, languages)
    TextPropertyValue.filter_preferred_languages(preferred_languages, product_ids).each do |language, property_ids|
      new_property_ids += property_ids
      
      property_ids.each do |property_id|
        filter = existing_filters[property_id]
        new_filters << TextFilter.new(:property_definition_id => property_id) if filter.nil?
      end
    end
    
    NumericPropertyValue.limits_by_unit_by_property_id(product_ids).each do |property_id, limits_by_unit|
      next if limits_by_unit.any? { |unit, min_max| min_max.compact.empty? }
      next unless filterable_property_ids.include?(property_id)
      new_property_ids << property_id
      
      filter = existing_filters[property_id]
      
      if filter.nil?
        new_filters << NumericFilter.new(:property_definition_id => property_id, :limits => limits_by_unit)
      else
        filter.limits = limits_by_unit
      end
    end
    
    # TODO: spec this functionality
    filters.all(:property_definition_id => existing_filters.keys - new_property_ids).each { |filter| filter.destroy }
    filters.push(*new_filters)
    
    self.executed_at = Time.now
    save and filters.reload
  end
  
  def filtered_product_ids    
    return [] if all_product_count.zero?
    
    used_filters = filters(:fresh => false)
    return all_product_ids if used_filters.empty?
    
    # TODO: spec examples where this kicks in
    query =<<-EOS
      SELECT DISTINCT product_id
      FROM property_values
      WHERE product_id IN ?
        AND property_definition_id IN ?
    EOS
    used_filter_pdids = used_filters.map { |filter| filter.property_definition_id }
    relevant_product_ids = repository.adapter.query(query, all_product_ids, used_filter_pdids)
    return [] if relevant_product_ids.empty?
    
    relevant_product_ids - excluded_product_ids(relevant_product_ids, used_filters)
  end
  
  # TODO: spec
  def text_values_by_relevant_filter_id
    product_ids_by_pid = Filter.product_ids_by_property_id(filtered_product_ids)
    text_values = TextFilter.values_by_property_id(product_ids_by_pid, language_code)
        
    values_by_fid = {}
    filters.each do |filter|
      property_id = filter.property_definition_id
      next if filter.fresh? and (product_ids_by_pid[property_id] || []).empty?
      values_by_fid[filter.id] = text_values[property_id]
    end
    values_by_fid
  end
  
  # TODO: spec
  def reset
    filters.all.each { |filter| filter.destroy }
    filters.reload
    execute!
  end
  
  def spec_date
    if executed_at.nil? then specification
    else "#{specification} (#{executed_at.strftime('%Y/%m/%d %H:%M:%S')})"
    end
  end


  private
  
  # TODO: revise in light of the core filtering changes
  def excluded_product_ids(product_ids, used_filters)
    query_chunks = []
    query_bind_values = []
    used_filters.each do |filter|
      query, *bind_values = filter.excluded_product_query_chunk(language_code)
      next if query.nil?
      query_chunks << query
      query_bind_values += bind_values
    end
    
    return [] if query_chunks.empty?
    
    query = "SELECT DISTINCT product_id FROM property_values WHERE product_id IN ? AND ("
    query += query_chunks.map { |chunk| "(#{chunk})"}.join(" OR ")
    query += ")"
    repository.adapter.query(query, product_ids, *query_bind_values)
  end
end
