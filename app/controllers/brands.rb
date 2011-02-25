class Brands < Application
  def show(name)
    @brand = Brand.first(:name => name)
    return render("../cached_finds/new".to_sym, :status => 404) if @brand.nil?
    
    product_ids_by_node = @brand.product_ids_by_category_node
    product_ids = product_ids_by_node.values.flatten
    
    product_ids_by_checksum = Indexer.image_checksums_for_product_ids(product_ids)
    checksums_by_product_id = {}
    product_ids_by_checksum.each do |checksum, product_ids|
      product_ids.each { |product_id| checksums_by_product_id[product_id] = checksum }
    end
    
    @checksums_by_node = {}
    product_ids_by_node.each do |node, product_ids|
      @checksums_by_node[node] = checksums_by_product_id.values_at(*product_ids).uniq
    end
    
    @assets_by_checksum = Asset.all(:checksum => product_ids_by_checksum.keys).hash_by(:checksum)
    
    @titles_by_checksum = {}
    @urls_by_checksum = {}
    product_ids_by_checksum.each do |checksum, product_ids|
      product_id = product_ids.first
      @titles_by_checksum[checksum] = [:image, :summary].map { |domain| Indexer.product_title(domain, product_id) }
      @urls_by_checksum[checksum] = Indexer.product_url(product_id)
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
