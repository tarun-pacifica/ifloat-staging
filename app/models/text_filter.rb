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
  
  # TODO: consider moving to TextPropertyValue
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
        AND f.language_code = pv.language_code
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
  
  def exclude!(value)
    return unless valid_exclusion?(value)
    # TODO: switch to more convenient methods when DM bug is fixed that causes odd extra lookups
    TextFilterExclusion.create(:text_filter_id => id, :value => value) if valid_exclusion?(value)
    # self.fresh = exclusions.create(:value => value) if valid_exclusion?(value)
    self.fresh = false
    save! # TODO: remove (!) when DM bug is fixed that causes the fresh state to get reset to the DB value
  end
  
  def excluded_product_query_chunk(language_code)
    query =<<-EOS
      property_definition_id = ? AND
      language_code = ? AND
      text_value IN (SELECT value FROM text_filter_exclusions WHERE text_filter_id = ?)
    EOS
    
    [query, property_definition_id, language_code, self.id]
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
    product_ids = cached_find.all_product_ids
    return false if product_ids.empty?
    
    insert =<<-EOI
      INSERT INTO text_filter_exclusions (text_filter_id, value)
      SELECT DISTINCT ?, text_value
      FROM property_values
      WHERE product_id IN ?
        AND property_definition_id = ?
        AND language_code = ?
        AND text_value NOT IN (SELECT value FROM text_filter_exclusions WHERE text_filter_id = ?)
    EOI
    
    repository.adapter.execute(insert, id, product_ids, property_definition_id, cached_find.language_code, id)
    
    # TODO: switch to more convenient methods when DM bug is fixed that causes odd extra lookups
    TextFilterExclusion.all(:text_filter_id => id, :value => value).destroy!
    self.fresh = TextFilterExclusion.all(:text_filter_id => id).count.zero?
    # exclusions.all(:value => value).destroy!
    # self.fresh = exclusions.count.zero?
    save! # TODO: remove (!) when DM bug is fixed that causes the fresh state to get reset to the DB value
  end
  
  def text?
    true
  end
  
  def valid_exclusion?(value)
    product_ids = cached_find.all_product_ids
    return false if product_ids.empty?
    
    query =<<-EOS
      SELECT id
      FROM property_values
      WHERE product_id IN ?
        AND property_definition_id = ?
        AND language_code = ?
        AND text_value = ?
    EOS
    
    repository.adapter.query(query, product_ids, property_definition_id, cached_find.language_code, value).size > 0
  end
end