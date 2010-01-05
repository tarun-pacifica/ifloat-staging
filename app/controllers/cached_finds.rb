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
      CachedFindEvent.log!(specification, session[:recalled], request.remote_ip)
      redirect(resource(find))
    else redirect("/")
    end
  end
  
  def filter(id, property_id, operation)
    provides :js
    
    find = session.ensure_cached_find(id.to_i)
    return "reset".to_json if find.ensure_valid
    
    find.filter!(property_id.to_i, operation, params)    
    find.filter_values_relevant(*find.filter_values).to_json
  end
  
  def filters(id)
    provides :js
    
    find = session.ensure_cached_find(id.to_i)
    return "reset".to_json if find.ensure_valid
    
    filters = find.filters
    properties = PropertyDefinition.all(:id => filters.map { |filter| filter[:prop_id] })
    icon_urls = PropertyDefinition.icon_urls_by_property_id(properties)
    text_value_definitions = PropertyDefinition.definitions_by_property_id(properties, find.language_code)
    text_values, relevant_numeric_limits = find.filter_values
    relevant_values_by_prop_id = find.filter_values_relevant(text_values, relevant_numeric_limits)
    
    filters.each do |filter|
      prop_id = filter[:prop_id]
      filter[:icon_url] = icon_urls[prop_id]
      filter[:relevant] = relevant_values_by_prop_id.has_key?(prop_id)
      
      if filter[:prop_type] == "text"
        all_values, relevant_values = text_values[prop_id]
        definitions = text_value_definitions[prop_id]
        (definitions.keys - all_values).each { |v| definitions.delete(v) }
        filter[:data] = {
          :all         => all_values,
          :definitions => definitions,
          :excluded    => filter[:data],
          :relevant    => (relevant_values.sort == all_values ? "all" : relevant_values)
        }
      else
        filter[:data] = {
          :chosen => filter[:data][0..2].map { |v| v.nil? ? "" : v },
          :limits => filter[:data][3]
        }
      end
    end
    
    filters.to_json
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
    
    checksums.map do |checksum|
      asset = assets_by_checksum[checksum]
      [checksum, totals_by_checksum[checksum], asset.url(:small), asset.url(:tiny)]
    end.unshift(total).to_json
  end
  
  def found_products_for_checksum(id, image_checksum)
    find = session.ensure_cached_find(id.to_i)
    find.ensure_valid
    
    product_ids = find.filtered_product_ids_by_image_checksum[image_checksum]
    @product_count = product_ids.size
    return redirect(resource(find)) if product_ids.nil? or product_ids.empty?
    
    return redirect(url(:product, :id => product_ids.first)) if product_ids.size == 1
    
    @image = Asset.first(:checksum => image_checksum)
    return redirect(resource(find)) if @image.nil?
    
    @values_by_property_by_product_id = Product.display_values(product_ids, session.language)
    
    value_identities_by_property = {}
    @values_by_property_by_product_id.each do |product_id, values_by_property|
      values_by_property.each do |property, values|
        next unless property.display_as_data?
        
        value_identity = values.map do |value|
          v = value.value
          parts = (v.is_a?(Range) ? [v.first, v.last] : [v])
          parts << value.unit unless value.class.text? or value.unit.nil?
          parts
        end.sort
        (value_identities_by_property[property] ||= []).push(value_identity)
      end
    end
    
    properties = value_identities_by_property.keys
    @common_properties, @diff_properties = properties.partition do |property|
      value_identities_by_property[property].uniq.size == 1
    end.map do |prop_segment|
      prop_segment.sort_by { |p| p.sequence_number }
    end
    
    @values_by_property = {}
    @values_by_property_by_product_id.values.first.each do |property, values|
      @values_by_property[property] = values if @common_properties.include?(property)
    end
    
    @product_ids_by_value_by_unit_by_property = {}
    @values_by_property_by_product_id.each do |product_id, values_by_property|
      values_by_property.each do |property, values|
        next unless @diff_properties.include?(property)
        product_ids_by_value_by_unit = (@product_ids_by_value_by_unit_by_property[property] ||= {})
        values.each do |value|
          product_ids_by_value = (product_ids_by_value_by_unit[value.class.text? ? nil : value.unit] ||= {})
          (product_ids_by_value[value.value] ||= []).push(product_id)
        end
      end
    end
    
    @friendly_name_sections = PropertyDefinition.friendly_name_sections(properties, session.language)
    @icon_urls_by_property_id = PropertyDefinition.icon_urls_by_property_id(properties)
    @text_value_definitions = PropertyDefinition.definitions_by_property_id(properties, session.language)
    
    @values_by_property_by_product_url = {}
    product_ids.each do |product_id|
      url = url(:product, :id => product_id)
      @values_by_property_by_product_url[url] = nil
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
    
    @previous_finds = session.cached_finds
    render
  end
end
