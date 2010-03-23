class CachedFinds < Application
  def compare_by_image(id, image_checksum)
    @find = session.ensure_cached_find(id.to_i)
    @find.ensure_valid
    
    product_ids = @find.filtered_product_ids_by_image_checksum[image_checksum]
    return redirect(resource(find)) if product_ids.nil? or product_ids.empty?
    return redirect(url(:product, :id => product_ids.first)) if product_ids.size == 1
    
    @image = Asset.first(:checksum => image_checksum)
    return redirect(resource(find)) if @image.nil?
    
    @common_values, diff_values = Product.marshal_values(product_ids, session.language, RANGE_SEPARATOR)
    
    diff_dad_values = diff_values.select { |info| info[:dad] }
    @diff_property_ids = diff_dad_values.map { |info| info[:id] }.uniq.sort_by do |property_id|
      Indexer.property_display_cache[property_id][:seq_num]
    end
    @diff_count = @diff_property_ids.size
    
    diff_prop_ids_in_comp_order = @diff_property_ids.dup
    @primary_property_id = params[:sort_by].to_i
    if diff_prop_ids_in_comp_order.include?(@primary_property_id)
      diff_prop_ids_in_comp_order.delete(@primary_property_id)
      diff_prop_ids_in_comp_order.unshift(@primary_property_id)
    else
      @primary_property_id = diff_prop_ids_in_comp_order.first
    end
    
    @diff_values = diff_dad_values.group_by { |info| info[:product_id] }.sort_by do |product_id, values|
      values.group_by { |info| info[:id] }.values_at(*diff_prop_ids_in_comp_order).flatten.map do |info|
        info.nil? ? [] : info[:comp_key]
      end
    end
    
    title_property_names = %w(marketing:brand marketing:range marketing:model)
    @title_parts = Array.new(title_property_names.size) { Set.new }
    (@common_values + diff_values).each do |info|
      i = title_property_names.index(info[:raw_name])
      @title_parts[i] += info[:values] unless i.nil?
    end
    
    render
  end
  
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
    result = (params["method"] == "delete" ? find.unfilter!(property_id.to_i) : find.filter!(property_id.to_i, params))
    return nil.to_json unless result
    result = [find.filters_used(RANGE_SEPARATOR), find.filters_unused, gather_images(find)]
    (find.ensure_valid.empty? ? result : nil).to_json
  end
  
  def filters(id, list)
    provides :js
    raise NotFound unless %w(unused used).include?(list)
    find = session.ensure_cached_find(id.to_i)
    result = (list == "used" ? find.filters_used(RANGE_SEPARATOR) : find.filters_unused)
    (find.ensure_valid.empty? ? result : nil).to_json
  end
  
  def images(id)
    provides :js
    find = session.ensure_cached_find(id.to_i)
    result = gather_images(find)
    (find.ensure_valid.empty? ? result : nil).to_json # TODO: react to nil in JS
  end
  
  def new
    @show_purchases_button = session.picked_products.any? { |pick| pick.group =~ /^buy/ }
    render
  end
  
  def reset(id)
    find = session.ensure_cached_find(id.to_i)
    return nil.to_json unless find.unfilter_all!
    result = [find.filters_used(RANGE_SEPARATOR), find.filters_unused, gather_images(find)]
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
    @find.accessed_at = DateTime.now
    @find.ensure_valid
    @find.save
    
    render
  end
  
  
  private
  
  def gather_images(find)
    total = 0
    totals_by_checksum = {}
    find.filtered_product_ids_by_image_checksum.each do |checksum, product_ids|
      total += (totals_by_checksum[checksum] = product_ids.size)
    end
    
    checksums = totals_by_checksum.keys[0, 36]
    assets_by_checksum = {}
    Asset.all(:checksum => checksums).each { |a| assets_by_checksum[a.checksum] = a }
    
    checksums.map do |checksum|
      asset = assets_by_checksum[checksum]
      [checksum, totals_by_checksum[checksum], asset.url(:tiny), asset.url(:small)]
    end.unshift(total)
  end
end
