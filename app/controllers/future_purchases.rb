class FuturePurchases < Application
  def buy(facility_id)
    facility = Facility.get(facility_id) 
    raise NotFound if facility.nil?
    return redirect("/future_purchases/buy_options") if facility.primary_url.nil?
    
    @future_purchases, @current_purchases = session.future_purchases.partition { |purchase| purchase.deferred? }
    return redirect("/future_purchases/buy_options") if @current_purchases.empty?
    
    current_prod_ids = @current_purchases.map { |purchase| purchase.definitive_product_id }
    product_ids = current_prod_ids + @future_purchases.map { |purchase| purchase.definitive_product_id }
    fac_prods_by_def_prod_id = facility.map_products(product_ids)
    @purchase_titles_by_product_id = purchase_titles(product_ids)
            
    @partner_product_urls = {}
    fac_prods_by_def_prod_id.each do |definitive_product_id, facility_product|
      @partner_product_urls[definitive_product_id] = partner_product_url(facility, facility_product.reference)
    end
    
    fap = first_available_product(@current_purchases, fac_prods_by_def_prod_id)
    @partner_url = partner_url(facility, fap)
    return redirect("/future_purchases/buy_options") if @partner_url.nil?
    
    purchase_refs = fac_prods_by_def_prod_id.values_at(*current_prod_ids).compact.map { |fp| fp.reference }
    purchase = Purchase.new(:facility => facility, :product_refs => purchase_refs)
    session.add_purchase(purchase)
    
    @transitional = true
    render
  end
  
  def buy_options
    all_purchases = session.future_purchases
    return redirect("/") if all_purchases.empty?
    
    @shopping_list = []
    @future_buys = []
    @product_ids = []
    shopping_list_product_ids = []
    all_purchases.each do |purchase|
      (purchase.deferred? ? @future_buys : @shopping_list) << purchase
      @product_ids << purchase.definitive_product_id
      shopping_list_product_ids << purchase.definitive_product_id unless purchase.deferred?
    end
    
    @prices_by_url_by_product_id = Product.prices(@product_ids, session.currency)
    @facility_urls = ["marinestore.co.uk"]
    # this is hard-coded in order to simplify the buy options page, this will need review as more facilities are added
    # note that the following lookup and logic would also probably be obviated by a change in this code
    
    facility_ids = {}
    Facility.all(:primary_url => @facility_urls).each do |facility|
      facility_ids[facility.primary_url] = facility.id
    end
    
    @totals_info = {}
    @facility_urls.each do |url|
      prices = []
      shopping_list_product_ids.each do |product_id|
        price = (@prices_by_url_by_product_id[product_id] || {})[url]
        prices << price unless price.nil?
      end

      @totals_info[url] = [facility_ids[url], prices.size, prices.reduce(:+)]
    end
    
    @previous_finds = session.cached_finds
    render
  end
  
  def create(product_id, deferred)
    raise Unauthenticated unless deferred == "false" or session.authenticated?
    raise NotFound unless DefinitiveProduct.get(product_id)
    session.add_future_purchase(FuturePurchase.new(:definitive_product_id => product_id, :deferred => deferred))
    ""
  end
  
  def delete(id)
    purchase = session.ensure_future_purchase(id.to_i)
    purchase.destroy
    session.remove_future_purchase(purchase)
    ""
  end
  
  def index
    @purchases = session.future_purchases    
    product_ids = @purchases.map { |purchase| purchase.definitive_product_id }
    @purchase_titles_by_product_id = purchase_titles(product_ids)
    partial :purchase, :with => @purchases
  end
  
  def update(id)
    purchase = session.ensure_future_purchase(id.to_i)
    purchase.deferred = (not purchase.deferred)
    raise Unauthenticated unless purchase.deferred == false or session.authenticated?
    purchase.save
    ""
  end
  
  
  private
  
  def first_available_product(current_purchases, facility_products)
    current_purchases.each do |purchase|
      product = facility_products[purchase.definitive_product_id]
      return product unless product.nil?
    end
    nil
  end
  
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
  
  def purchase_titles(product_ids)
    purchase_titles_by_product_id = Hash.new("")
    Product.display_values(product_ids, session.language, ["auto:title"]).each do |product_id, values_by_property|
      title_property, titles = values_by_property.first
      purchase_titles_by_product_id[product_id] = titles.last
    end
    purchase_titles_by_product_id
  end
end
