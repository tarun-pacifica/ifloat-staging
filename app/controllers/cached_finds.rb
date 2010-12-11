class CachedFinds < Application
  def compare_by_image(id, image_checksum)
    product_ids =
      if id == 0
        Indexer.product_ids_for_image_checksum(image_checksum)
      else
        @find = session.ensure_cached_find(id.to_i)
        @find.ensure_valid
        @find.filtered_product_ids_by_image_checksum[image_checksum]
      end
    
    related_to = params[:related_to]
    product_ids &= Indexer.product_relationships(related_to.to_i).values.flatten unless related_to.nil?
    
    retreat if product_ids.nil?
    return redirect(Indexer.product_url(product_ids.first)) if product_ids.size == 1
    
    @image = Asset.first(:checksum => image_checksum)
    retreat if @image.nil?
    
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
    
    @title_parts = [:image, :summary].map { |domain| Indexer.product_title(domain, product_ids.first.to_i) }
    
    class_infos = (@common_values + diff_values).select { |info| info[:raw_name] == "reference:class" }
    classes = class_infos.map { |info| info[:values] }.flatten.uniq
    @primary_class = classes.first
    
    @find ||= session.most_recent_cached_find
    render
  end
  
  def create(language_code, specification)
    find = session.add_cached_find(CachedFind.new(:language_code => language_code, :specification => specification))
    
    if find.valid?
      recalled = (not find.accessed_at.nil?)
      CachedFindEvent.log!(find.specification, recalled, request.remote_ip)
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
    
    result = [find.filters_used(RANGE_SEPARATOR), find.filters_unused, marshal_images(find.filtered_product_ids, 36)]
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
    result = marshal_images(find.filtered_product_ids, 36)
    (find.ensure_valid.empty? ? result : nil).to_json
  end
  
  def new
    render
  end
  
  def reset(id)
    find = session.ensure_cached_find(id.to_i)
    return nil.to_json unless find.unfilter_all!
    result = [find.filters_used(RANGE_SEPARATOR), find.filters_unused, marshal_images(find.filtered_product_ids, 36)]
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
  
  def retreat
    @find.nil? ? render("../cached_finds/new".to_sym, :status => 404) : redirect(resource(@find))
  end
end
