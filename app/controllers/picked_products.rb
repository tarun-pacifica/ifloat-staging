class PickedProducts < Application
  def buy(facility_id)
    facility = Facility.get(facility_id) 
    raise NotFound if facility.nil?
    return redirect("/picked_products/buy_options") if facility.primary_url.nil?
    
    @picks_by_group = session.picked_products.group_by { |pick| pick.group }
    return redirect("/picked_products/buy_options") if @picks_by_group["buy_now"].empty?
    
    prod_ids_by_group = {}
    @picks_by_group.each do |group, picks|
      prod_ids_by_group[group] = picks.map { |pick| pick.product_id }
    end
    
    product_ids = prod_ids_by_group.values.flatten
    fac_prods_by_prod_id = facility.map_products(product_ids)
    @pick_titles_by_product_id = titles(product_ids)
            
    @partner_product_urls = {}
    fac_prods_by_prod_id.each do |product_id, facility_product|
      @partner_product_urls[product_id] = partner_product_url(facility, facility_product.reference)
    end
    
    first_available_product = fac_prods_by_prod_id.values_at(*prod_ids_by_group["buy_now"]).compact.first
    @partner_url = partner_url(facility, first_available_product)
    return redirect("/picked_products/buy_options") if @partner_url.nil?
    
    session.add_purchase(Purchase.new(:facility => facility))
    
    @transitional = true
    render
  end
  
  def buy_options
    @picks_by_group = session.picked_products.group_by { |pick| pick.group }
    return redirect("/") if @picks_by_group["buy_later"].nil? and @picks_by_group["buy_now"].nil?
    
    prod_ids_by_group = {}
    @picks_by_group.each do |group, picks|
      prod_ids_by_group[group] = picks.map { |pick| pick.product_id }
    end
    
    # TODO: should be able to remove once product batch rendering is client side
    @product_ids = prod_ids_by_group.values_at("buy_later", "buy_now").flatten
    @prices_by_url_by_product_id = Product.prices(@product_ids, session.currency)
    
    @counts_by_url = Hash.new(0)
    @totals_by_url = Hash.new(0)
    @prices_by_url_by_product_id.values_at(*prod_ids_by_group["buy_now"]).compact.each do |prices_by_url|
      prices_by_url.each do |url, price|
        @counts_by_url[url] += 1
        @totals_by_url[url] += price
      end
    end
    
    @facilities_by_url = Facility.all.hash_by { |facility| facility.primary_url }
    @facility_urls = (@counts_by_url.empty? ? @facilities_by_url.keys : @counts_by_url.keys).sort
    
    render
  end
  
  def create(product_id, group)
    raise Unauthenticated unless group != "buy_later" or session.authenticated?
    raise NotFound unless Product.get(product_id)
    session.add_picked_product(PickedProduct.new(:product_id => product_id, :group => group))
    ""
  end
  
  def delete(id)
    pick = session.ensure_picked_product(id.to_i)
    session.remove_picked_products([pick])
    ""
  end
  
  def index
    provides :js
    
    picks = session.picked_products
    titles_by_product_id = titles(picks.map { |pick| pick.product_id })
    
    picks_by_group = {}
    picks.each do |pick|
      product_id = pick.product_id
      title_parts = titles_by_product_id[product_id]
      url = url(:product, :id => product_id)
      
      pick_group = (picks_by_group[pick.group] ||= [])
      pick_group << [url, title_parts]
    end
    
    compare_picks = picks_by_group["compare"]
    unless compare_picks.nil?
      compare_picks_by_class = compare_picks.group_by { |url, title_parts| title_parts.last }
      picks_by_group["compare"] = compare_picks_by_class.map do |klass, picks_info|
        ["/product_picks/compare/#{klass}", [klass, picks_info.size]]
      end
    end
    
    picks_by_group.to_json
  end
  
  def update(id, group)
    raise Unauthenticated unless group != "buy_later" or session.authenticated?
    pick = session.ensure_picked_product(id.to_i)
    pick.group = group
    pick.save
    ""
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
  
  def titles(product_ids)
    property_names = %w(marketing:brand reference:class)
    
    titles_by_product_id = Hash.new("")
    Product.display_values(product_ids, session.language, property_names).each do |product_id, values_by_property|
      parts = {}
      values_by_property.each { |property, values| parts[property.name] = values.first.to_s }
      titles_by_product_id[product_id] = parts.values_at(*property_names).compact
    end
    titles_by_product_id
  end
end
