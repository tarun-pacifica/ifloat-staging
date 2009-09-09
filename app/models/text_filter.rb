# = Summary
#
# See the Filter superclass.
#
class TextFilter < Filter
	has n, :exclusions, :class_name => "TextFilterExclusion", :child_key => [:text_filter_id]
	
	before :destroy do
	  exclusions.destroy!
  end
  
  # TODO: review all class methods as may now be defunct
  def self.exclusions_by_filter_id(filter_ids)
    exclusions = {}
    TextFilterExclusion.all(:text_filter_id => filter_ids).each do |exclusion|
      (exclusions[exclusion.text_filter_id] ||= []) << exclusion.value
    end
    exclusions
  end
  
  # TODO: consider moving to TextPropertyValue - at least the first uniq the flattern
  def self.values_by_property_id(product_ids_by_property_id, language_code)
    product_ids = product_ids_by_property_id.values.flatten
    property_ids = product_ids_by_property_id.keys
    return {} if product_ids.empty? or property_ids.empty?
    
    # TODO: consider a query that uses the structure of product_ids_by_property_id
    query =<<-EOS
      SELECT DISTINCT property_definition_id AS pdid, text_value AS value
      FROM property_values
      WHERE product_id IN ?
        AND property_definition_id IN ?
        AND language_code = ?
      ORDER BY value ASC
    EOS
    
    values_by_pid = {}
    repository.adapter.query(query, product_ids, property_ids, language_code).map do |record|
      values = (values_by_pid[record.pdid] ||= [])
      values << record.value
    end
    values_by_pid
  end
  
  # TODO: remove
  def self.values_by_filter_id(cached_find)
	  product_ids = cached_find.all_product_ids
	  return {} if product_ids.empty?
    
    query =<<-EOS
    SELECT DISTINCT f.id AS fid, pv.text_value AS value, tfe.id AS id
    FROM filters f
      INNER JOIN property_values pv 
        ON f.property_definition_id = pv.property_definition_id
      LEFT JOIN text_filter_exclusions tfe
        ON f.id = tfe.text_filter_id AND pv.text_value = tfe.value
    WHERE f.cached_find_id = ?
      AND pv.product_id IN ?
      AND pv.text_value IS NOT NULL
    EOS
        
    filter_values = {}
    repository.adapter.query(query, cached_find.id, product_ids).map do |record|
      values = (filter_values[record.fid] ||= [])
      values << [record.value, record.id.nil?]
    end
    filter_values
  end
  
  # TODO: spec
  def all_values
    product_ids, language = cached_find.all_product_ids, cached_find.language_code
    values_by_property_id = Indexer.filterable_text_values_for_product_ids(product_ids, [], language, false)
    values_by_property_id[property_definition_id].first
  end
  
  def exclude!(value)
    return unless valid_exclusion?(value)
    # TODO: switch to more convenient methods when DM bug is fixed that causes odd extra lookups
    TextFilterExclusion.create(:text_filter_id => id, :value => value) if all_values.include?(value)
    # self.fresh = exclusions.create(:value => value) if valid_exclusion?(value)
    self.fresh = false
    save! # TODO: remove (!) when DM bug is fixed that causes the fresh state to get reset to the DB value
  end
  
  def include!(value)
    # TODO: switch to more convenient methods when DM bug is fixed that causes odd extra lookups
    TextFilterExclusion.all(:text_filter_id => id, :value => value).destroy!
    self.fresh = TextFilterExclusion.all(:text_filter_id => id).count.zero?
    # exclusions.all(:value => value).destroy!
    # self.fresh = exclusions.count.zero?
    save! # TODO: remove (!) when DM bug is fixed that causes the fresh state to get reset to the DB value
  end
  
  # TODO: SPEC
  def include_only!(value)
    existing_values = TextFilterExclusion.all(:text_filter_id => id).map { |tfe| tfe.value }
    (all_values - existing_values).each { |v| TextFilterExclusion.create(:text_filter_id => id, :value => v) unless v == value }
    
    # TODO: switch to more convenient methods when DM bug is fixed that causes odd extra lookups
    TextFilterExclusion.all(:text_filter_id => id, :value => value).destroy! if existing_values.include?(value)
    self.fresh = TextFilterExclusion.all(:text_filter_id => id).count.zero?
    # exclusions.all(:value => value).destroy!
    # self.fresh = exclusions.count.zero?
    save! # TODO: remove (!) when DM bug is fixed that causes the fresh state to get reset to the DB value
  end
  
  def text?
    true
  end
  
  def valid_exclusion?(value)
    product_ids, language = cached_find.all_product_ids, cached_find.language_code
    values_by_property_id = Indexer.filterable_text_values_for_product_ids(product_ids, [], language, false)
    all, relevant = values_by_property_id[property_definition_id]
    all.include?(value)
  end
end