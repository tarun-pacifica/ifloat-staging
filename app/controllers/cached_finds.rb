class CachedFinds < Application
  def conversions
    provides :js
    
    @conversions = {}
    Conversion::MAPPINGS.each do |from_to, ab_values|
      @conversions[from_to.join(">>")] = ab_values
    end
    
    render
  end
  
  def create(language_code, specification)
    cf = session.add_cached_find(CachedFind.new(:language_code => language_code, :specification => specification))
    
    if cf.valid?
      session[:recalled] = (not cf.accessed_at.nil?)
      redirect(resource(cf))
    else redirect("/")
    end
  end
  
  def found_product_ids(id, limit)
    provides :js
    
    cached_find = session.ensure_cached_find(id.to_i)
    cached_find.ensure_valid
    limit = [limit.to_i, 1].max
    product_ids = cached_find.filtered_product_ids
    ([product_ids.size] + product_ids[0, limit]).to_json
  end
  
  def new
    @cached_find = CachedFind.new(:language_code => session.language)
    @future_purchases = session.future_purchases
    @previous_finds = session.cached_finds
    render
  end
  
  def reset(id)
    cached_find = session.ensure_cached_find(id.to_i)
    cached_find.reset
    redirect(resource(cached_find))
  end
  
  def show(id)
    find_id = id.to_i
    begin
      @find = session.ensure_cached_find(find_id)
    rescue NotFound
      if session.authenticated? and find_id == session[:most_recent_find_id]
        defunct_cf = CachedFind.get(find_id)
        @find = session.cached_finds.find { |cf| cf.specification == defunct_cf.specification }
        session[:recalled] = (not @find.nil?)
      end
      return redirect(@find.nil? ? "/" : resource(@find))
    end
    
    @recalled = session[:recalled]
    session[:recalled] = false
    session[:most_recent_find_id] = @find.id
    @find.accessed_at = DateTime.now
    @find.ensure_valid
    @find.save
        
    filters = @find.filters
    property_ids = filters.map { |filter| filter.property_definition_id }
    properties = PropertyDefinition.all(:id => property_ids).map
    @filters = filters.sort_by { |filter| filter.property_definition.sequence_number }
    
    @text_filter_values, @relevant_filters = @find.filter_values
    
    @friendly_name_sections = PropertyDefinition.friendly_name_sections(property_ids, @find.language_code)
    @icon_urls_by_property_id = PropertyDefinition.icon_urls_by_property_id(properties)
    @text_value_definitions = PropertyValueDefinition.definitions_by_property_id(property_ids, @find.language_code)
        
    @previous_finds = session.cached_finds
    render
  end
end
