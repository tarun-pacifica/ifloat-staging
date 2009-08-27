class Filters < Application
  before :retrieve_filter
  provides :js
  
  def choose(min, max, unit)
    unit = nil if unit == ""
    @filter.choose!(min.to_f, max.to_f, unit)
    filter_update
  end

  def exclude(value)
    @filter.exclude!(value)
    filter_update
  end
  
  def include(value)
    @filter.include!(value)
    filter_update
  end
  
  def include_only(value)
    @filter.include_only!(value)
    filter_update
  end
  
  
  private
  
  def filter_update
    return "reset".to_json if @find.ensure_executed
    @find.text_values_by_relevant_filter_id.to_json
  end
  
  def retrieve_filter
    find_id, filter_id = params.values_at(:find_id, :filter_id).map { |i| i.to_i }
    @find = session.ensure_cached_find(find_id)
    @filter = @find.filters.get(filter_id)
    raise NotFound if @filter.nil?
  end
end
