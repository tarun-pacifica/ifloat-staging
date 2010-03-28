class Products < Application  
  def batch(ids)
    product_ids = ids.split("_").map { |id| id.to_i }.uniq[0, 100]
    
    images_by_product_id = Product.primary_images_by_product_id(product_ids)
    
    names = %w(auto:title marketing:summary)
    Product.values_by_property_name_by_product_id(product_ids, session.language, names).map do |product_id, values_by_property_name|
      { :id         => product_id,
        :image_urls => product_image_urls(images_by_product_id[product_id]),
        :titles     => (values_by_property_name["auto:title"] || []).map { |t| t.to_s },
        :summary    => (values_by_property_name["marketing:summary"] || []).first.to_s }
    end.to_json
  end
  
  def show(id)
    product_id = id.to_i
    @product = Product.get(product_id)
    return redirect("/") if @product.nil?
    
    @common_values, diff_values = @product.marshal_values(session.language, RANGE_SEPARATOR)
    
    names = %w(auto:title marketing:description marketing:feature_list marketing:summary reference:wikipedia).to_set
    @body_values_by_name = {}
    @common_values.each do |info|
      raw_name = info[:raw_name]
      @body_values_by_name[raw_name] = info[:values] if names.include?(raw_name)
    end
    
    gather_assets(@product)
    
    @prices_by_url = @product.prices_by_url(session.currency)
    @price_unit, @price_divisor = UnitOfMeasure.unit_and_divisor_by_product_id([product_id])[product_id]
    
    @related_products_by_rel_name = ProductRelationship.related_products(@product)
    @related_products_by_rel_name.delete_if { |name, products| products.empty? } # TODO: work out why we have to do this
    
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
        @related_media << [name, assets.first.url]
      else
        assets.each_with_index do |asset, i|
          @related_media << ["#{name} #{i + 1}", asset.url]
        end
      end
    end
        
    (@body_values_by_name["reference:wikipedia"] || []).each do |stub|
      title = stub.split("_").map { |word| word[0..0].upcase + word[1..-1] }.join(" ")
      @related_media << ["#{title.inspect} Wikipedia Article", "http://en.wikipedia.org/wiki/#{stub}"]
    end
  end
end
