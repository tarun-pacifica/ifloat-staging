# = Summary
#
# See the Filter superclass.
#
class TextFilter < Filter
	has n, :exclusions, :class_name => "TextFilterExclusion", :child_key => [:text_filter_id]
	
	before :destroy do
	  exclusions.destroy!
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
  
  
  private
  
  def all_values
    product_ids, language = cached_find.all_product_ids, cached_find.language_code
    values_by_property_id = Indexer.filterable_text_values_for_product_ids(product_ids, [], language, false)
    values_by_property_id[property_definition_id].first
  end
end