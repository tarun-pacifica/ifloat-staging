class FuturePurchases < Application
  def buy(facility_id)
    facility = Facility.get(facility_id) 
    raise NotFound if facility.nil?
    return redirect("/future_purchases/buy_options") if facility.primary_url.nil?
    
    @future_purchases, @current_purchases = session.future_purchases.partition { |purchase| purchase.deferred? }
    return redirect("/future_purchases/buy_options") if @current_purchases.empty?
    
    current_product_ids = @current_purchases.map { |purchase| purchase.definitive_product_id }
    facility_products = facility.map_products(current_product_ids)
    
    product_ids = current_product_ids + @future_purchases.map { |purchase| purchase.definitive_product_id }
    unused_values, @auto_titles_by_product_id = Product.display_values(product_ids, session.languages)
            
    @partner_product_urls = {}
    facility_products.each do |definitive_product_id, facility_product|
      @partner_product_urls[definitive_product_id] = partner_product_url(facility, facility_product.reference)
    end
    
    fap = first_available_product(@current_purchases, facility_products)
    @partner_url = partner_url(facility, fap)
    return redirect("/future_purchases/buy_options") if @partner_url.nil?
    
    purchase = Purchase.new(:facility => facility, :product_refs => facility_products.map { |fp| fp.reference } )
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
    all_purchases.each do |purchase|
      (purchase.deferred? ? @future_buys : @shopping_list) << purchase
      @product_ids << purchase.definitive_product_id
    end
    
    @prices = Product.prices(@product_ids, session.currency)
    @facility_urls = ["marinestore.co.uk"]
    # this is hard-coded in order to simplify the buy options page, this will need review as more facilities are added
    # note that the following lookup and logic would also probably be obviated by a change in this code
    
    facility_ids = {}
    Facility.all(:primary_url => @facility_urls).each do |facility|
      facility_ids[facility.primary_url] = facility.id
    end
    
    @totals_info = {}
    @facility_urls.each do |url|
      facility_id = facility_ids[url]
      prices = @prices.values.map { |prices_by_facility_id| prices_by_facility_id[facility_id] }.compact
      @totals_info[url] = [facility_id, prices.size, prices.reduce(:+)]
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
    unused_values, @auto_titles_by_product_id = Product.display_values(product_ids, session.languages)
    render :layout => false
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
  
  def partner_product_url(facility, product)
    case facility.primary_url
    when "marinestore.co.uk"
      "http://marinestore.co.uk/Merchant2/merchant.mvc?Screen=PROD&Product_Code=#{product.reference}"
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
