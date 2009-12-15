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
  
  def found_images(id, limit)
    provides :js
    
    find = session.ensure_cached_find(id.to_i)
    find.ensure_valid
    
    total = 0
    totals_by_checksum = {}
    find.filtered_product_ids_by_image_checksum.each do |checksum, product_ids|
      total += (totals_by_checksum[checksum] = product_ids.size)
    end
    
    limit = [limit.to_i, 1].max
    checksums = totals_by_checksum.keys[0, limit]
    assets_by_checksum = {}
    Asset.all(:checksum => checksums).each { |a| assets_by_checksum[a.checksum] = a }
    p assets_by_checksum.size
    p checksums.size
    p checksums - assets_by_checksum.keys
    
    checksums.map do |checksum|
      asset = assets_by_checksum[checksum]
      [checksum, totals_by_checksum[checksum], asset.url(:small), asset.url(:tiny)]
    end.unshift(total).to_json
  end
  
  def found_products(id, image_checksum)
    find = session.ensure_cached_find(id.to_i)
    find.ensure_valid
    
    product_ids = find.filtered_product_ids_by_image_checksum[image_checksum]
    return redirect(resource(find)) if product_ids.nil? or product_ids.empty?
    
    return redirect(url(:product, :id => product_ids.first)) if product_ids.size == 1
    
    @image = Asset.first(:checksum => image_checksum)
    return redirect(resource(find)) if @image.nil?
    
    @values_by_property_by_product_id = Product.display_values(product_ids, session.language)
    
    product_ids_by_value_by_property = {}
    @values_by_property_by_product_id.each do |product_id, values_by_property|
      values_by_property.each do |property, value|
        product_ids_by_value = (product_ids_by_value_by_property[property] ||= {})
        (product_ids_by_value[value] ||= []).push(product_id)
      end
    end
    
    @properties = product_ids_by_value_by_property.keys.sort_by { |property| property.sequence_number }
    @friendly_name_sections = PropertyDefinition.friendly_name_sections(@properties, session.language)
    @icon_urls_by_property_id = PropertyDefinition.icon_urls_by_property_id(@properties)
    @text_value_definitions = PropertyDefinition.definitions_by_property_id(@properties, session.language)
    
    # TODO: split up values
    @common_values = {}
    @differential_values = {}
    product_ids_by_value_by_property.each do |property, product_ids_by_value|
      if product_ids_by_value.size == 1 then @common_values[property] = product_ids_by_value.first.first
      else @differential_values[property] = product_ids_by_value.keys
      end
    end
    
    @previous_finds = session.cached_finds
    @recent_find = CachedFind.get(session[:most_recent_find_id])
    render
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
