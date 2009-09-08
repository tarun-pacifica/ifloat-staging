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
      last_indexer_compile = Indexer.last_compile
      should_execute = (last_indexer_compile >= executed_at) unless last_indexer_compile.nil?
    end
    execute! if should_execute
    should_execute
  end

  def execute!
    raise "cannot execute invalid CachedFind" unless valid?
    raise "cannot execute unsaved CachedFind" if new_record?
    
    product_ids = Indexer.product_ids_for_phrase(specification, language_code)
    self.product_id_list = product_ids.join(",")
    
    existing_filters = {}
    NumericFilter.all(:cached_find_id => id).each { |f| existing_filters[f.property_definition_id] = f }
    TextFilter.all(:cached_find_id => id).each { |f| existing_filters[f.property_definition_id] = f }
    
    to_save = []
    new_property_ids = []
    
    Indexer.filterable_text_property_ids_for_product_ids(product_ids, false).each do |property_id|
      new_property_ids << property_id      
      filter = existing_filters[property_id]
      to_save << TextFilter.new(:cached_find_id => id, :property_definition_id => property_id) if filter.nil?
    end
    
    Indexer.numeric_limits_for_product_ids(product_ids, false).each do |property_id, limits_by_unit|
      next if limits_by_unit.any? { |unit, min_max| min_max == [nil, nil] }
      new_property_ids << property_id
      
      filter = existing_filters[property_id]
      filter = NumericFilter.new(:cached_find_id => id, :property_definition_id => property_id) if filter.nil?
      filter.limits = limits_by_unit
      to_save << filter if filter.dirty?
    end
    
    # TODO: spec this functionality
    existing_filters.each { |property_id, filter| filter.destroy unless new_property_ids.include?(property_id) }
    to_save.each { |filter| filter.save }
    
    self.executed_at = Time.now
    save
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
