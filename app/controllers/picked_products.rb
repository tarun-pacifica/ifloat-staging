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
    
    prod_ids_by_group.delete("compare")
    
    mappings = facility.product_mappings(prod_ids_by_group.values.flatten)
    @partner_product_urls = facility.product_urls(mappings)
    
    one_off_product_id = params[:product_id].to_i
    purchase_product_ids = (one_off_product_id > 0 ? [one_off_product_id] : prod_ids_by_group["buy_now"]).to_set
    @purchase_urls = facility.purchase_urls(mappings.select { |m| purchase_product_ids.include?(m.product_id) })
    return redirect("/picked_products/options") if @purchase_urls.empty?
    
    purchase = Purchase.new(:facility => facility, :created_ip => request.remote_ip)
    session.add_purchase(purchase)
    Mailer.deliver(:purchase_started,
      :one_off  => params[:product_id],
      :picks    => session.picked_products,
      :purchase => purchase)
    
    @background_css = "white"
    @skip_copyright = true
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
    @picks_by_product_id = picks.hash_by(:product_id)
    @product_ids = @picks_by_product_id.keys
    
    return redirect("/") if @product_ids.empty?
    return redirect(Indexer.product_url(@product_ids.first)) if @product_ids.size == 1
    
    forced_diff_props = %w(marketing:summary marketing:feature_list).to_set
    @common_values, diff_values = Product.marshal_values(@product_ids, session.language, RANGE_SEPARATOR, forced_diff_props)
    
    @diff_values_by_prop_id = diff_values.select do |info|
      info[:dad] or forced_diff_props.include?(info[:raw_name])
    end.group_by { |info| info[:id] }
    
    @diff_properties = @diff_values_by_prop_id.keys.map do |property_id|
      Indexer.property_display_cache[property_id]
    end.sort_by do |info|
      case info[:raw_name]
      when "marketing:summary" then -2
      when "marketing:feature_list" then -1
      else info[:seq_num]
      end
    end
    
    @images_by_product_id = Product.primary_images_by_product_id(@product_ids)
    
    @formatted_prices_by_product_id = Hash.new { "None of our partners have this item in stock" }
    unit_and_divisor_by_product_id = UnitOfMeasure.unit_and_divisor_by_product_id(@product_ids)
    Product.prices_by_url_by_product_id(@product_ids, session.currency).each do |product_id, prices_by_url|
      price = prices_by_url.values.min
      unit, divisor = unit_and_divisor_by_product_id[product_id]
      @formatted_prices_by_product_id[product_id] = money_uom(price, session.currency, unit, divisor)
    end
    @sale_price_property_info = Indexer.property_display_cache[Indexer.sale_price_min_property_id]
    
    @find = session.most_recent_cached_find
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
        :url         => Indexer.product_url(product_id)
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
          :url         => "/picked_products/products_for/#{Merb::Parse.escape(klass)}" }
      end
    end
    
    picks_by_group.to_json
  end
  
  def options
    non_compare_picks = session.picked_products.reject { |pick| pick.group == "compare" }
    return redirect("/") if non_compare_picks.empty?
    
    @picks_by_product_id = non_compare_picks.hash_by(:product_id) # TODO: check whether needed
    product_ids = @picks_by_product_id.keys
    
    @prices_by_url_by_product_id = Product.prices_by_url_by_product_id(product_ids, session.currency)
    unit_and_divisor_by_product_id = UnitOfMeasure.unit_and_divisor_by_product_id(product_ids)
    
    @prices_by_url_by_product_id.each do |product_id, prices_by_url|
      unit, divisor = unit_and_divisor_by_product_id[product_id]
      
      formatted_prices_by_url = {}
      prices_by_url.each do |url, price|
        formatted_prices_by_url[url] = money_uom(price, session.currency, unit, divisor)
      end
      
      prices_by_url.update(formatted_prices_by_url)
    end
    
    @facility_descriptions_by_url = {}
    @facility_ids_by_url = {}
    Indexer.facilities.each do |url, facility|
      @facility_descriptions_by_url[url] = facility[:description]
      @facility_ids_by_url[url] = facility[:id]
    end
    @facility_urls = Indexer.facilities.keys
    
    render
  end
  
  def update(id, group)
    raise Unauthenticated unless group != "buy_later" or session.authenticated?
    pick = session.ensure_picked_product(id.to_i)
    pick.group = group
    pick.save
    index
  end
end
