class Products < Application
  def batch(ids)
    provides :js
    
    product_ids = ids.split("_").map { |id| id.to_i }.uniq[0, 100]
    images_by_product_id = Product.primary_images_by_product_id(product_ids)
    
    product_ids.map do |product_id|
      image = images_by_product_id[product_id]
      titles = Hash[[:canonical, :image, :summary].map { |k| [k, Indexer.product_title(k, product_id)] }]
      url = Indexer.product_url(product_id)
      
      {:id => product_id, :image_urls => image.urls_by_variant, :titles => titles, :url => url}
    end.to_json
  end
  
  def show(id)
    product_id = id.to_i
    @canonical_path = Indexer.product_url(product_id)
    return redirect(@canonical_path, :status => 301) unless @canonical_path.nil? or @canonical_path == request.path
    
    @product = Product.get(product_id)
    return categories_404(product_id < Indexer.max_product_id ? 410 : 404) if @product.nil?
    
    @common_values, diff_values = @product.marshal_values(session.language, RANGE_SEPARATOR)
    
    names = %w(marketing:brand marketing:description marketing:feature_list reference:category reference:class reference:wikipedia sale:pack_quantity).to_set
    @body_values_by_name = {}
    @common_values.each do |info|
      raw_name = info[:raw_name]
      @body_values_by_name[raw_name] = info[:values] if names.include?(raw_name)
    end
    
    @brand = Brand.first(:name => @body_values_by_name["marketing:brand"])
    
    @title, @summary, @page_description =
      [:canonical, :summary, :description].map { |domain| Indexer.product_title(domain, product_id) }
    @page_title = @title.desuperscript
    
    gather_assets(@product)
    
    prices_by_url = @product.prices_by_url(session.currency)
    @price_unit, price_divisor = UnitOfMeasure.unit_and_divisor_by_product_id([product_id])[product_id]
    @pack_quantity = [(@body_values_by_name["sale:pack_quantity"] || []).first.to_i, 1].max
    
    amount = prices_by_url.values.first # TODO: generalise this once we have more than one partner
    @price = money_uom(amount, session.currency, @price_unit, price_divisor)
    @price_each = money((amount || 0) / @pack_quantity, session.currency, @price_unit) if @pack_quantity > 1
    
    @product_links_by_rel_name, @rel_product_ids = marshal_product_links(Indexer.product_relationships(product_id))
    
    klass = @body_values_by_name["reference:class"]
    sibling_data = @product.sibling_properties_with_prod_ids_and_values(session.language, klass)
    
    @sibling_prod_ids_by_value_by_prop_ids = {}
    sibling_data.each do |property, prod_ids_with_values|
      prod_ids_by_values = (@sibling_prod_ids_by_value_by_prop_ids[property[:id]] ||= {})
      prod_ids_with_values.each do |prod_id, value|
        (prod_ids_by_values[value] ||= []) << prod_id
      end
    end
    
    @sibling_prod_ids_by_value_by_prop_ids.delete_if do |prop_id, prod_ids_by_value|
      prod_ids_by_value.size == 1 and prod_ids_by_value.values.first.size > 1
    end
    
    @sibling_properties = sibling_data.map do |property, prod_ids_with_values|
      property if @sibling_prod_ids_by_value_by_prop_ids.has_key?(property[:id])
    end.compact
    
    render
  end
  
  
  private
  
  def gather_assets(product)
    assets_by_role = product.assets_by_role
    
    @image_urls = (assets_by_role.delete("image") || []).map { |asset| asset.url }
    @image_urls << "/images/common/no_image.png" if @image_urls.empty?
    
    @related_media = []
    assets_by_role.sort.each do |role, assets|
      name = Attachment::ROLES[role]
      
      if assets.size == 1
        url = assets.first.url
        @related_media << [name, url, icon_for_url(url)]
      else
        assets.each_with_index do |asset, i|
          url = asset.url
          @related_media << ["#{name} #{i + 1}", url, icon_for_url(url)]
        end
      end
    end
        
    (@body_values_by_name["reference:wikipedia"] || []).each do |stub|
      title = stub.split("_").map { |word| word[0..0].upcase + word[1..-1] }.join(" ")
      url = "http://en.wikipedia.org/wiki/#{stub}"
      @related_media << ["#{title.inspect} Wikipedia Article", url, icon_for_url(url)]
    end
  end
  
  def icon_for_url(url)
    "/images/common/icons/" +
      case url
      when Asset::IMAGE_FORMAT then "image.png"
      when /\.pdf$/ then "pdf.png"
      else "link.png"      
      end
  end
end
