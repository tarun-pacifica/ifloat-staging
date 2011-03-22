class Brands < Application
  def show(name, root = nil, sub = nil)
    name = URI.unescape(name)
    @brand = Brand.first(:name => name)
    return categories_404 if @brand.nil?
    
    path_names = [root, sub].compact.map { |n| n.tr("+", " ") }
    product_ids_by_node = @brand.product_ids_by_category_node(path_names)
    return categories_404 if product_ids_by_node.empty?
    
    @product_links_by_node, @product_ids = marshal_product_links(product_ids_by_node)
    
    @brand_url = "/brands/#{URI.escape(name)}"
    @canonical_path = [@brand_url, root, sub].compact.join("/")
    @page_description = @brand.description
    @page_title = ([name] + path_names).join(" - ")
    render
  end
end
