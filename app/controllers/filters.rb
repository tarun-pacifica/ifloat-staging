class Filters < Application
  provides :js
  
  def choose(min, max, unit)
    retrieve_filter
    return "reset".to_json if @reset
    
    unit = nil if unit == ""
    @filter.choose!(min.to_f, max.to_f, unit)
    filter_update
  end

  def exclude(value)
    retrieve_filter
    return "reset".to_json if @reset
    
    @filter.exclude!(value)
    filter_update
  end
  
  def include(value)
    retrieve_filter
    return "reset".to_json if @reset
    
    @filter.include!(value)
    filter_update
  end
  
  def include_only(value)
    retrieve_filter
    return "reset".to_json if @reset
    
    @filter.include_only!(value)
    filter_update
  end
  
  
  private
  
  def filter_update
    text_filter_values, relevant_filters = @find.filter_values(false)
    relevant_filters.to_json
  end
  
  def retrieve_filter
    find_id, filter_id = params.values_at(:find_id, :filter_id).map { |i| i.to_i }
    @find = session.ensure_cached_find(find_id)
    @reset = @find.ensure_valid
    @filter = Filter.first(:cached_find_id => find_id, :id => filter_id)
    raise NotFound if @filter.nil?
  end
end
