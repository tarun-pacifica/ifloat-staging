class Products < Application
  def batch(ids)
    product_ids = ids.split("_").map { |id| id.to_i }.uniq[0..99]
    
    images_by_product_id = Product.primary_images(product_ids)
    property_names = %w(auto:title marketing:summary)
    values_by_property_by_product_id = Product.display_values(product_ids, session.language, property_names)
    
    properties = values_by_property_by_product_id.values.map { |vbp| vbp.keys }.flatten.uniq
    title_property, summary_property = properties.hash_by(:name).values_at(*property_names)
    
    product_ids.map do |product_id|
      values_by_property = values_by_property_by_product_id[product_id]
      
      { :id         => product_id,
        :image_urls => product_image_urls(images_by_product_id[product_id]),
        :titles     => (values_by_property[title_property] || []).map { |t| t.to_s },
        :summary    => (values_by_property[summary_property] || []).first.to_s }
    end.to_json
  end
  
  def show(id)
    product_id = id.to_i
    @product = Product.get(product_id)
    return redirect("/") if @product.nil?
    
    gather_property_values(@product)
    gather_assets(@product)
    
    @icon_urls_by_property_id = PropertyDefinition.icon_urls_by_property_id(@data_properties)
    @prices_by_url = @product.prices(session.currency)
    
    @related_products_by_rel_name = ProductRelationship.related_products(@product)
    @related_products_by_rel_name.delete_if { |name, products| products.empty? }
    
    @recent_find = session.most_recent_cached_find
    render
  end
  
  private
  
  def gather_assets(product)
    assets_by_role = product.role_assets
    
    @image_urls = (assets_by_role.delete("image") || []).map { |asset| asset.url }
    @image_urls << "/images/products/no_image.png" if @image_urls.empty?
    
    @asset_urls_with_names = []
    assets_by_role.sort.each do |role, assets|
      next if role == "source_notes"
      
      name = role.tr("_", " ").downcase.gsub(/\b\w/) { |s| s.upcase }

      if assets.size == 1
        @asset_urls_with_names << [assets.first.url, name]
      else
        assets.each_with_index do |asset, i|
          @asset_urls_with_names << [asset.url, "#{name} #{i}"]
        end
      end
    end
        
    wikipedia_stub = (@non_data_values["reference:wikipedia"].first rescue nil)
    @asset_urls_with_names << ["http://en.wikipedia.org/wiki/#{wikipedia_stub}", "Wikipedia Article"] unless wikipedia_stub.nil?
  end
  
  def gather_property_values(product)
    @values_by_property = product.display_values(session.language)
    
    @data_properties = []
    @non_data_values = {}
    non_data_property_names = ["auto:title", "marketing:description", "marketing:feature_list", "marketing:summary", "reference:wikipedia"]
    
    @values_by_property.each do |property, values|
      if non_data_property_names.include?(property.name)
        @non_data_values[property.name] = values
      elsif property.display_as_data?
        @data_properties << property
      end
    end
    
    @data_properties = @data_properties.sort_by { |property| property.sequence_number }
    @friendly_name_sections = PropertyDefinition.friendly_name_sections(@data_properties, session.language)
    @text_value_definitions = PropertyDefinition.definitions_by_property_id(@data_properties, session.language)
  end
end
