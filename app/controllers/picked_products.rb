class PickedProducts < Application
  def buy(facility_id)
    facility = Facility.get(facility_id) 
    raise NotFound if facility.nil?
    return redirect("/") if facility.primary_url.nil?
    
    prod_ids_by_group = {}
    session.picked_products.each do |pick|
      (prod_ids_by_group[pick.group] ||= []).push(pick.product_id)
    end
    return redirect("/") unless prod_ids_by_group.has_key?("buy_now")
    
    prod_ids_by_group.delete("compare")
    
    mappings = facility.product_mappings(prod_ids_by_group.values.flatten)
    @partner_product_urls = facility.product_urls(mappings)
    
    one_off_product_id = params[:product_id].to_i
    purchase_product_ids = (one_off_product_id > 0 ? [one_off_product_id] : prod_ids_by_group["buy_now"]).to_set
    @purchase_urls = facility.purchase_urls(mappings.select { |m| purchase_product_ids.include?(m.product_id) })
    return redirect("/") if @purchase_urls.empty?
    
    Mailer.deliver(:purchase_started,
      :url     => facility.primary_url,
      :one_off => one_off_product_id,
      :picks   => session.picked_products,
      :from_ip => request.remote_ip,
      :userish => session.userish)
    
    @background_css = "white"
    @skip_copyright = true
    @transitional = true
    session.log!("GET", "picked_products_buy:#{one_off_product_id}:#{facility.primary_url}", request.remote_ip)
    render
  end
  
  def create(product_id, group, quantity)
    raise Unauthenticated unless group != "buy_later" or session.authenticated?
    raise NotFound unless Product.get(product_id)
    session.add_picked_product(PickedProduct.new(:product_id => product_id, :group => group, :quantity => quantity))
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
    session.log!("GET", "picked_products_compare_by_class:#{klass}", request.remote_ip)
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
    prices_by_url_by_product_id = Product.prices_by_url_by_product_id(product_ids, session.currency)
    ud_by_product_id = UnitOfMeasure.unit_and_divisor_by_product_id(product_ids)
    
    basket_subtotal = 0.0
    picks_by_group = {}
    picks.each do |pick|
      product_id = pick.product_id
      quantity = (pick.quantity || 1)
      price = (prices_by_url_by_product_id[product_id] || {}).values.first
      
      (picks_by_group[pick.group] ||= []) << {
        :id          => pick.id,
        :product_id  => product_id,
        :image_urls  => images_by_product_id[product_id].urls_by_variant,
        :title_parts => pick.title_parts,
        :url         => Indexer.product_url(product_id),
        :quantity    => quantity,
        :unit        => (ud_by_product_id[product_id] || []).first,
        :subtotal    => price.nil? ? "N/A" : money(quantity * price, session.currency)
      }
      
      basket_subtotal += quantity * price if pick.group == "buy_now" and not price.nil?
    end
    
    picks_by_group["buy_now"] << money(basket_subtotal, session.currency) if basket_subtotal > 0
    
    compare_picks = picks_by_group["compare"]
    picks_by_group["compare"] = compare_picks.sort_by { |info| [info[:title_parts].last, info[:id]] } unless compare_picks.nil?
    
    picks_by_group.to_json
  end
  
  def update(id, group)
    raise Unauthenticated unless group != "buy_later" or session.authenticated?
    pick = session.ensure_picked_product(id.to_i)
    pick.group = group
    pick.save
    index
  end
end
