class CachedFinds < Application  
  def create(language_code, specification)
    find = session.add_cached_find(CachedFind.new(:language_code => language_code, :specification => specification))
    
    if find.valid?
      CachedFindEvent.log!(specification, (not find.accessed_at.nil?), request.remote_ip)
      redirect(resource(find))
    else
      redirect("/")
    end
  end
  
  def filter_get(id, property_id)
    provides :js
    find = session.ensure_cached_find(id.to_i)
    result = find.filter_detail(property_id.to_i)
    (find.ensure_valid.empty? ? result : nil).to_json
  end
  
  def filter_set(id, property_id)
    provides :js
    find = session.ensure_cached_find(id.to_i)
    return nil.to_json unless find.filter!(property_id.to_i, params)
    result = [find.filters_used("&ndash;"), find.filters_unused, found_images(id, 36, true)]
    (find.ensure_valid.empty? ? result : nil).to_json
  end
  
  def filters(id, list)
    provides :js
    raise NotFound unless %w(unused used).include?(list)
    find = session.ensure_cached_find(id.to_i)
    result = (list == "used" ? find.filters_used("&ndash;") : find.filters_unused)
    (find.ensure_valid.empty? ? result : nil).to_json
  end
  
  # TODO: get rid of 'raw' hack and do a proper refactoring and ensure this method runs the ensure_valid logic
  def found_images(id, limit, raw = false)
    provides :js
    
    find = session.ensure_cached_find(id.to_i)
    
    total = 0
    totals_by_checksum = {}
    find.filtered_product_ids_by_image_checksum.each do |checksum, product_ids|
      total += (totals_by_checksum[checksum] = product_ids.size)
    end
    
    limit = [limit.to_i, 1].max
    checksums = totals_by_checksum.keys[0, limit]
    assets_by_checksum = {}
    Asset.all(:checksum => checksums).each { |a| assets_by_checksum[a.checksum] = a }
    
    results = checksums.map do |checksum|
      asset = assets_by_checksum[checksum]
      [checksum, totals_by_checksum[checksum], asset.url(:tiny), asset.url(:small)]
    end.unshift(total)
    
    (raw ? results : results.to_json)
  end
  
  def found_products_for_checksum(id, image_checksum)
    find = session.ensure_cached_find(id.to_i)
    find.ensure_valid
    
    product_ids = find.filtered_product_ids_by_image_checksum[image_checksum]
    return redirect(resource(find)) if product_ids.nil? or product_ids.empty?
    return redirect(url(:product, :id => product_ids.first)) if product_ids.size == 1
    
    @image = Asset.first(:checksum => image_checksum)
    return redirect(resource(find)) if @image.nil?
    
    @values_by_property_by_product_id = Product.display_values(product_ids, session.language)    
    @common_properties, @diff_properties = Product.partition_data_properties(@values_by_property_by_product_id)
    
    primary_property_id = params[:sort_by].to_i
    properties_in_comparison_order = @diff_properties.sort_by do |p|
      p.id == primary_property_id ? -1 : p.sequence_number
    end
    @primary_property = properties_in_comparison_order.first
    
    @sorted_product_ids = product_ids.sort_by do |product_id|
      values_by_property = @values_by_property_by_product_id[product_id]
      properties_in_comparison_order.map do |property|
        values = values_by_property[property]
        values.nil? ? [] : values.map { |v| v.comparison_key }.min
      end
    end
    
    @values_by_property = {}
    @values_by_property_by_product_id.values.first.each do |property, values|
      @values_by_property[property] = values if @common_properties.include?(property)
    end
    
    properties = (@common_properties + @diff_properties)
    @friendly_name_sections = PropertyDefinition.friendly_name_sections(properties, session.language)
    @icon_urls_by_property_id = PropertyDefinition.icon_urls_by_property_id(properties)
    @text_value_definitions = PropertyDefinition.definitions_by_property_id(properties, session.language)
    
    properties_by_name = properties.hash_by(:name)
    title_properties = properties_by_name.values_at("marketing:brand", "marketing:range", "marketing:model")
    @title_parts = @values_by_property_by_product_id.map do |product_id, values_by_property|
      values_by_property.values_at(*title_properties).compact.map do |values_for_property|
        values_for_property.map { |value| value.to_s }
      end
    end.transpose.map { |set| set.flatten.uniq! }
    
    render
  end
  
  def new
    @show_purchases_button = session.picked_products.any? { |pick| pick.group =~ /^buy/ }
    render
  end
  
  def reset(id)
    find = session.ensure_cached_find(id.to_i)
    return nil.to_json unless find.unfilter_all!
    result = [find.filters_used("&ndash;"), find.filters_unused, found_images(id, 36, true)]
    (find.ensure_valid.empty? ? result : nil).to_json
  end
  
  def show(id)
    find_id = id.to_i
    begin
      @find = session.ensure_cached_find(find_id)
    rescue NotFound
      defunct_find = session.most_recent_cached_find
      @find = session.cached_finds.find { |cf| cf.specification == defunct_find.specification } if session.authenticated? and find_id == defunct_find.id
      return redirect(@find.nil? ? "/" : resource(@find))
    end
    
    session.most_recent_cached_find = @find
    @find.accessed_at = DateTime.now # TODO: move to ensure_cached_find? - only used for expiry now
    @find.ensure_valid
    @find.save
    
    render
  end
end
