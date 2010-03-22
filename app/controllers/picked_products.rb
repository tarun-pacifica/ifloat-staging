class PickedProducts < Application
  def buy(facility_id)
    facility = Facility.get(facility_id) 
    raise NotFound if facility.nil?
    return redirect("/picked_products/options") if facility.primary_url.nil?
    
    prod_ids_by_group = {}
    session.picked_products.each do |pick|
      (prod_ids_by_group[pick.group] ||= []).push(pick.product_id)
    end
    return redirect("/picked_products/options") unless prod_ids_by_group.has_key?("buy_now")
    
    product_ids = prod_ids_by_group.values.flatten
    fac_prods_by_prod_id = facility.map_products(product_ids)
            
    @partner_product_urls = {}
    fac_prods_by_prod_id.each do |product_id, facility_product|
      @partner_product_urls[product_id] = partner_product_url(facility, facility_product.reference)
    end
    
    first_available_product = fac_prods_by_prod_id.values_at(*prod_ids_by_group["buy_now"]).compact.first
    @partner_url = partner_url(facility, first_available_product)
    return redirect("/picked_products/options") if @partner_url.nil?
    
    session.add_purchase(Purchase.new(:facility => facility, :created_ip => request.remote_ip))
    
    @transitional = true
    render
  end
  
  def create(product_id, group)
    raise Unauthenticated unless group != "buy_later" or session.authenticated?
    raise NotFound unless Product.get(product_id)
    session.add_picked_product(PickedProduct.new(:product_id => product_id, :group => group))
    index
  end
  
  def compare_by_class(klass)
    klass = Merb::Parse.unescape(klass)
    picks = session.picked_products.select { |pick| pick.group == "compare" and pick.cached_class == klass }
    @product_ids = picks.map { |pick| pick.product_id }
    
    return redirect("/") if @product_ids.empty?
    return redirect(url(:product, :id => @product_ids.first)) if @product_ids.size == 1
    
    @common_values, diff_values = Product.marshal_values(@product_ids, session.language, RANGE_SEPARATOR)
    
    @diff_values_by_prop_id = diff_values.select { |info| info[:dad] }.group_by { |info| info[:id] }
    
    @diff_properties = @diff_values_by_prop_id.keys.map do |property_id|
      Indexer.property_display_cache[property_id]
    end.sort_by { |info| info[:seq_num] }
    
    @images_by_product_id = Product.primary_images_by_product_id(@product_ids)
    
    render
  end
  
  def delete(id)
    pick = session.ensure_picked_product(id.to_i)
    session.remove_picked_products([pick])
    index
  end
  
  def index
    provides :js
    
    picks = session.picked_products
    product_ids = picks.map { |pick| pick.product_id }
    images_by_product_id = Product.primary_images_by_product_id(product_ids)
    
    picks_by_group = {}
    picks.each do |pick|
      product_id = pick.product_id
      (picks_by_group[pick.group] ||= []) << {
        :id          => pick.id,
        :product_id  => product_id,
        :image_urls  => product_image_urls(images_by_product_id[product_id]),
        :title_parts => pick.title_parts,
        :url         => url(:product, :id => product_id)
      }
    end
    
    compare_picks = picks_by_group["compare"]
    unless compare_picks.nil?
      compare_picks_by_class = compare_picks.group_by { |info| info[:title_parts].last }
      picks_by_group["compare"] = compare_picks_by_class.map do |klass, info_for_picks|
        { :ids         => info_for_picks.map { |info| info[:id] },
          :product_ids => info_for_picks.map { |info| info[:product_id] },
          :image_urls  => info_for_picks.map { |info| info[:image_urls] }.compact.first,
          :title_parts => [klass, info_for_picks.size],
          :url         => "/picked_products/compare_by_class/#{Merb::Parse.escape(klass)}" }
      end
    end
    
    picks_by_group.to_json
  end
  
  def options
    non_compare_picks = session.picked_products.reject { |pick| pick.group == "compare" }
    return redirect("/") if non_compare_picks.empty?
    
    product_ids = non_compare_picks.map { |pick| pick.product_id }
    @prices_by_url_by_product_id = Product.prices_by_url_by_product_id(product_ids, session.currency)
    @prices_by_url_by_product_id.values.each do |prices_by_url|
      formatted_prices_by_url = {}
      prices_by_url.each do |url, price|
        formatted_prices_by_url[url] = money(price, session.currency)
      end
      prices_by_url.update(formatted_prices_by_url)
    end
    
    # TODO: replace simplified logic with a DB lookup based on @prices_by_url_by_product_id when > 1 partners
    @facility_ids_by_url = {}
    Facility.all.each do |facility|
      @facility_ids_by_url[facility.primary_url] = facility.id
    end
    @facility_urls = @facility_ids_by_url.keys
    
    render
  end
  
  def update(id, group)
    raise Unauthenticated unless group != "buy_later" or session.authenticated?
    pick = session.ensure_picked_product(id.to_i)
    pick.group = group
    pick.save
    index
  end
  
  
  private
  
  def partner_product_url(facility, reference)
    case facility.primary_url
    when "marinestore.co.uk"
      "http://marinestore.co.uk/Merchant2/merchant.mvc?Screen=PROD&Product_Code=#{reference}"
    else nil
    end
  end
  
  def partner_url(facility, first_available_product)
    case facility.primary_url
    when "marinestore.co.uk"
      url = "http://marinestore.co.uk/Merchant2/merchant.mvc"
      url += "?Screen=PROD&Product_Code=#{first_available_product.reference}" unless first_available_product.nil?
      url
    else nil
    end
  end
end
