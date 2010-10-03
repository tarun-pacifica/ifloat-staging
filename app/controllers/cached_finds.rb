class CachedFinds < Application
  def compare_by_image(id, image_checksum)
    @find = session.ensure_cached_find(id.to_i)
    @find.ensure_valid
    
    product_ids = @find.filtered_product_ids_by_image_checksum[image_checksum]
    return redirect(resource(@find)) if product_ids.nil? or product_ids.empty?
    return redirect(Indexer.product_url(product_ids.first)) if product_ids.size == 1
    
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
    
    class_infos = (@common_values + diff_values).select { |info| info[:raw_name] == "reference:class" }
    classes = class_infos.map { |info| info[:values] }.flatten.uniq
    @primary_class = classes.first
    
    render
  end
  
  def create(language_code, specification)
    specification = specification.downcase
    find = session.add_cached_find(CachedFind.new(:language_code => language_code, :specification => specification))
    
    if find.valid?
      recalled = (not find.accessed_at.nil?)
      CachedFindEvent.log!(specification, recalled, request.remote_ip)
      find.unfilter_all! if params[:unfiltered] == "true" and recalled
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
    
    return nil.to_json unless params["reset_filters"] != "true" or find.unfilter_all!
    
    return nil.to_json unless
      (params["method"] == "delete" ?
       find.unfilter!(property_id.to_i) :
       find.filter!(property_id.to_i, params))
    
    primary_class = params["primary_class"]
    return nil.to_json unless primary_class.blank? or find.filter!(Indexer.class_property_id, "value" => primary_class)
    
    return nil.to_json unless params["inline_response"] == "true"
    
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
    (find.ensure_valid.empty? ? result : nil).to_json
  end
  
  def new
    @tags = []
    min, max = Indexer.tag_frequencies.values.minmax
    unless min.nil?
      normalised_max = (max - min) / 4.0 
      @tags = Indexer.tag_frequencies.sort.map! do |tag, frequency|
        [tag, ((frequency - min) / normalised_max).round]
      end
    end
   
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
      return redirect("/") if defunct_find.nil? or not session.authenticated? or find_id != defunct_find.id
      @find = session.cached_finds.find { |cf| cf.specification == defunct_find.specification }
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
    product_ids_by_checksum = find.filtered_product_ids_by_image_checksum
    total = product_ids_by_checksum.values.inject(0) { |sum, product_ids| sum + product_ids.size }
    checksums = product_ids_by_checksum.keys[0, 36]
    
    totals_by_checksum = {}
    checksums.each do |checksum|
      totals_by_checksum[checksum] = product_ids_by_checksum[checksum].size
    end
    
    assets_by_checksum = Asset.all(:checksum => checksums).hash_by(:checksum)
    
    title_checksums_by_product_id = {}
    checksums.each do |checksum|
      product_id = product_ids_by_checksum[checksum].first
      title_checksums_by_product_id[product_id] = checksum
    end
    
    titles_by_checksum = {}
    Product.values_by_property_name_by_product_id(title_checksums_by_product_id.keys, session.language, %w(auto:title_image)).map do |product_id, values_by_property_name|
      checksum = title_checksums_by_product_id[product_id]
      titles_by_checksum[checksum] = (values_by_property_name["auto:title_image"] || []).map { |t| t.to_s }
    end
    
    checksums.map do |checksum|
      asset = assets_by_checksum[checksum]
      [checksum, totals_by_checksum[checksum], asset.url(:tiny), asset.url(:small), titles_by_checksum[checksum]]
    end.unshift(total)
  end
end
