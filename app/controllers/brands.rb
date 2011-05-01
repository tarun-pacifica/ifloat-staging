class Brands < Application
  def show(name)
    name = URI.unescape(name)
    @brand = Brand.first(:name => name)
    return categories_404 if @brand.nil?
    
    @canonical_path = "/brands/#{URI.escape(@brand.name)}"
    return redirect(@canonical_path, :status => 301) unless @canonical_path == request.path
    
    product_ids_by_node = @brand.product_ids_by_category_node([])
    return categories_404 if product_ids_by_node.empty?
    
    @product_links_by_node, @product_ids = marshal_product_links(product_ids_by_node)
    
    @show_all_links_by_node = {}
    product_ids_by_node.keys.each do |node|
      brand_filter = [Indexer.brand_property_id, "ENG", name, nil]
      count = @product_links_by_node[node].size
      @show_all_links_by_node[node] = category_link(node, "show all #{count}", [brand_filter])
    end
    
    @page_description = @brand.description
    @page_title = name
    render
  end
end
