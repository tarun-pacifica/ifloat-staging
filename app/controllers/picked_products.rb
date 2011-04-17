class PickedProducts < Application
  def buy(facility_id)
    facility = Facility.get(facility_id) 
    raise NotFound if facility.nil?
    return redirect("/") if facility.primary_url.nil?
    
    picks = session.picked_products.select { |pick| pick.group == "buy_now" }
    return redirect("/") if picks.empty?
    
    picks_by_product_id = picks.hash_by(:product_id)
    mappings = facility.product_mappings(picks_by_product_id.keys)
    mappings_with_quantities = mappings.map { |m| [m, picks_by_product_id[m.product_id].quantity] }
    @purchase_urls = facility.purchase_urls(mappings_with_quantities)
    return redirect("/") if @purchase_urls.empty?
    
    Mailer.deliver(:purchase_started,
      :url     => facility.primary_url,
      :picks   => session.picked_products,
      :from_ip => request.remote_ip,
      :userish => session.userish(request)) if Merb.environment == "production"
    
    @skip_copyright = true
    @transitional = true
    session.log!("GET", "picked_products_buy:#{facility.primary_url}", request.remote_ip)
    render
  end
  
  def create(product_id, group, quantity)
    raise Unauthenticated unless group != "buy_later" or session.authenticated?
    raise NotFound unless Product.get(product_id)
    quantity = [1, quantity.to_i].max if group == "buy_now"
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
    headers["Cache-Control"] = "max-age=0"
    
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
  
  def update(id, quantity)
    pick = session.ensure_picked_product(id.to_i)
    pick.quantity = quantity if quantity.to_i > 0
    pick.save
    index
  end
end
