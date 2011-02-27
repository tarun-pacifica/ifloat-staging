class Brands < Application
  def show(name, root = nil, sub = nil)
    name = URI.unescape(name)
    @brand = Brand.first(:name => name)
    return render("../cached_finds/new".to_sym, :status => 404) if @brand.nil?
    
    path_names = [root, sub].compact.map { |n| n.tr("+", " ") }
    
    product_ids_by_node = @brand.product_ids_by_category_node(path_names)
    all_product_ids = product_ids_by_node.values.flatten
    return render("../cached_finds/new".to_sym, :status => 404) if all_product_ids.empty?
    
    checksums_by_product_id = {}
    product_ids_by_checksum = {}
    Indexer.image_checksums_for_product_ids(all_product_ids).each do |checksum, product_ids|
      checksums_by_product_id[product_ids.first] = checksum
      product_ids_by_checksum[checksum] = product_ids.first
    end
    
    images_by_checksum = Asset.all(:checksum => product_ids_by_checksum.keys).hash_by(:checksum)
    @product_ids = checksums_by_product_id.keys
    
    @product_links_by_node = {}
    product_ids_by_node.each do |node, product_ids|
      checksums = checksums_by_product_id.values_at(*(product_ids & @product_ids)).uniq.sort_by do |checksum|
        Indexer.product_title(:image, product_ids_by_checksum[checksum])
      end
      @product_links_by_node[node] = checksums.map do |checksum|
        product_link(product_ids_by_checksum[checksum], images_by_checksum[checksum])
      end
    end
    
    @brand_url = "/brands/#{URI.escape(name)}"
    @page_description = @brand.description
    @page_title = ([name] + path_names).join(" - ")
    render
  end
end
