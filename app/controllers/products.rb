class Products < Application
  def batch(ids)
    product_ids = ids.split("_").map { |id| id.to_i }.uniq[0..99]
    values_by_property_by_product_id, auto_titles_by_product_id = Product.display_values(product_ids, session.languages)
    
    @product_values = auto_titles_by_product_id
    
    values_by_property_by_product_id.each do |product_id, values_by_property|
      @product_values[product_id]["marketing:summary"] = "SUMMARY"
      
      values_by_property.each do |property, values|
        next unless property.name == "marketing:summary"
        @product_values[product_id][property.name] = values.first
        break
      end
    end
    
    @image_urls = Hash.new("/images/no_image.png")
    Attachment.product_role_assets(product_ids, false).each do |product_id, assets_by_role|
      product_images = assets_by_role["image"]
      @image_urls[product_id] = product_images.first.url unless product_images.nil?
    end
    
    render :layout => false
  end
  
  def purchase_buttons(id)
    @product_id = id.to_i
    @purchase = session.future_purchases.find { |purchase| purchase.definitive_product_id == @product_id }
    render :layout => false
  end
  
  def show(id)
    product_id = id.to_i
    @product = DefinitiveProduct.get(product_id)
    return redirect("/") if @product.nil?
    
    gather_property_values(@product)
    gather_assets(@product)
    
    @icon_urls_by_property_id = PropertyDefinition.icon_urls_by_property_id(@data_properties)
    
    @prices = @product.prices(session.currency)
    # TODO: remove test data
    @prices["marinestore.co.uk"] = 57.22
    
    @related_products_by_rel_name = Relationship.related_products(@product)
    @related_products_by_rel_name.delete_if { |name, products| products.empty? }
    
    @previous_finds = session.cached_finds
    @recent_find = CachedFind.get(session[:most_recent_find_id])
    render
  end
  
  private
  
  def gather_assets(product)
    assets_by_role = product.role_assets
    
    @image_urls = (assets_by_role.delete("image") || []).map { |asset| asset.url }
    @image_urls << "/images/no_image.png" if @image_urls.empty?
    
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
        
    wikipedia_stub = @non_data_values["reference:wikipedia"]
    @asset_urls_with_names << ["http://en.wikipedia.org/wiki/#{wikipedia_stub}", "Wikipedia Article"] unless wikipedia_stub.nil?
  end
  
  def gather_property_values(product)
    @values_by_property, auto_titles = product.display_values(session.languages)
    
    @data_properties = []
    @non_data_values = auto_titles
    non_data_property_names = ["marketing:description", "marketing:feature_list", "marketing:summary", "reference:wikipedia"]
    
    @values_by_property.each do |property, values|
      if non_data_property_names.include?(property.name)
        @non_data_values[property.name] = (values.first || "")
      elsif property.display_as_data?
        @data_properties << property
      end
    end
    
    @data_properties = @data_properties.sort_by { |property| property.sequence_number }
    data_property_ids = @data_properties.map { |property| property.id }
    @friendly_name_sections = PropertyDefinition.friendly_name_sections(data_property_ids, session.language)
    @text_value_definitions = PropertyValueDefinition.definitions_by_property_id(data_property_ids, session.language)
  end
end
