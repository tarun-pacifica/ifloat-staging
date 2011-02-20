class Brands < Application
  def show(name)
    @brand = Brand.first(:name => name)
    return render("../cached_finds/new".to_sym, :status => 404) if @brand.nil?
    
    @product_ids_by_node = @brand.product_ids_by_category_node
    product_ids = @product_ids_by_node.values.flatten
    product_ids_by_checksum = Indexer.image_checksums_for_product_ids(product_ids)
    
    @image_infos_by_product_id = {}
    marshal_images(product_ids)[1..-1].each do |info|
      product_id = product_ids_by_checksum[info[0]].first
      @image_infos_by_product_id[product_id] = info
    end
    
    # @page_description = @brand.description
    @page_title = "#{name}"
    render
  end
  
  
  private
  
  def image_src(name)
    image = Asset.first(:bucket => "blogs", :name.like => "#{name}%")
    image.nil? ? nil : image.url
  end
end
