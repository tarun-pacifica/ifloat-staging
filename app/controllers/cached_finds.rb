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
    find = session.add_cached_find(CachedFind.new(:language_code => language_code, :specification => specification))
    
    if find.valid?
      session[:recalled] = (not find.accessed_at.nil?)
      redirect(resource(find))
    else redirect("/")
    end
  end
  
  def filter(id, property_id, operation)
    provides :js
    
    find = session.ensure_cached_find(id.to_i)
    return "reset".to_json if find.ensure_valid
    
    find.filter!(property_id.to_i, operation, params)
    text_filter_values, relevant_filters = find.filter_values
    relevant_filters.to_json
  end
  
  def found_image_urls(id, limit)
    provides :js
    
    find = session.ensure_cached_find(id.to_i)
    find.ensure_valid
    
    total = 0
    totals_by_url = {}
    find.filtered_product_ids_by_image_url.each do |url, product_ids|
      next if url.nil? # TODO: decide whether we should allow for this
      total += (totals_by_url[url] = product_ids.size)
    end
    
    limit = [limit.to_i, 1].max
    totals_by_url.to_a[0, limit].unshift(total).to_json
  end
  
  def found_products(id, image_checksum)
    find = session.ensure_cached_find(id.to_i)
    find.ensure_valid
    
    image = Asset.first(:checksum => image_checksum)
    return redirect(resource(find)) if image.nil?
    
    product_ids = find.filtered_product_ids_by_image_url[image.url]
    return redirect(resource(find)) if product_ids.nil? or product_ids.empty?
    
    return redirect(url(:product, :id => product_ids.first)) if product_ids.size == 1
    
    product_ids.to_json # TODO: gather products and render them into selection list
  end
  
  def new
    @future_purchases = session.future_purchases
    @previous_finds = session.cached_finds
    render
  end
  
  def reset(id)
    find = session.ensure_cached_find(id.to_i)
    find.invalidated = true
    find.save
    redirect(resource(find))
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
    
    @filters = @find.filters
    properties = PropertyDefinition.all(:id => @filters.map { |filter| filter[:prop_id] })
    @icon_urls_by_property_id = PropertyDefinition.icon_urls_by_property_id(properties)
    @text_value_definitions = PropertyDefinition.definitions_by_property_id(properties, @find.language_code)
    @text_filter_values, @relevant_filters = @find.filter_values
    
    @previous_finds = session.cached_finds
    render
  end
end
