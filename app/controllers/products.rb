class Products < Application
  def batch(ids)
    product_ids = ids.split("_").map { |id| id.to_i }.uniq[0, 100]
    
    images_by_product_id = Product.primary_images_by_product_id(product_ids)
    
    product_ids.map do |product_id|
      { :id         => product_id,
        :image_urls => product_image_urls(images_by_product_id[product_id]),
        :title      => Indexer.product_title(:canonical, product_id),
        :summary    => Indexer.product_title(:summary, product_id),
        :url        => Indexer.product_url(product_id) }
    end.to_json
  end
  
  def buy_now(id, facility_id)
    raise NotFound unless Product.get(id)
    session.add_picked_product(PickedProduct.new(:product_id => id, :group => "buy_now"))
    redirect("/picked_products/buy/#{facility_id}?product_id=#{id}")
  end
  
  def show(id)
    product_id = id.to_i
    path = Indexer.product_url(product_id)
    return redirect(path, :status => 301) unless path.nil? or path == request.path
    
    @product = Product.get(product_id)
    return render("../cached_finds/new".to_sym, :status => (product_id < Indexer.max_product_id ? 410 : 404)) if @product.nil?
    
    @common_values, diff_values = @product.marshal_values(session.language, RANGE_SEPARATOR)
    
    names = %w(marketing:description marketing:feature_list reference:class reference:wikipedia).to_set
    @body_values_by_name = {}
    @common_values.each do |info|
      raw_name = info[:raw_name]
      @body_values_by_name[raw_name] = info[:values] if names.include?(raw_name)
    end
    @title, @summary, @page_description =
      [:canonical, :summary, :description].map { |domain| Indexer.product_title(domain, product_id) }
    @page_title = @title.desuperscript
    
    gather_assets(@product)
    
    @prices_by_url = @product.prices_by_url(session.currency)
    @price_unit, @price_divisor = UnitOfMeasure.unit_and_divisor_by_product_id([product_id])[product_id]
    
    rel_names_by_product_ids = {}
    (Indexer.product_relationships(product_id) || []).each do |name, product_ids|
      product_ids.each { |product_id| (rel_names_by_product_ids[product_id] ||= []) << name }
    end
    
    product_ids = rel_names_by_product_ids.keys
    product_ids_by_checksum = Indexer.image_checksums_for_product_ids(product_ids)
    @images_by_rel_name = {}
    marshal_images(product_ids).each do |info|
      product_ids = (product_ids_by_checksum[info[0]] || [])
      rel_names_by_product_ids.values_at(*product_ids).flatten.uniq.each do |name|
        (@images_by_rel_name[name] ||= []) << info
      end
    end
    
    @more_class = @body_values_by_name["reference:class"].first
    @more_tags = (Indexer.tags_for_product_id(product_id, session.language) || [])
    @more_counts = Hash[@more_tags.map { |tag| [tag, Indexer.product_ids_for_tag(tag, session.language).size] }]
    @more_counts[@more_class] = Indexer.product_ids_for_phrase(@more_class, session.language).size
    
    @find = session.most_recent_cached_find
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
    "/images/product_detail/icons/" +
      case url
      when Asset::IMAGE_FORMAT then "image.png"
      when /\.pdf$/ then "pdf.png"
      else "link.png"      
      end
  end
end
