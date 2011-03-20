class Categories < Application
  def show(root = nil, sub = nil)
    @path_names = [root, sub].compact.map { |name| name.tr("+", " ") }
    
    children = Indexer.category_children_for_node(@path_names)
    if children.empty?
      return render("../cached_finds/new".to_sym, :status => 404)
    elsif children.first.is_a?(Integer)
      product_links_by_node, @product_ids = marshal_product_links(:products => children)
      @product_links = product_links_by_node[:products]
    else
      @children_links = children.map { |child| category_link(@path_names + [child]) }.sort
    end
    
    @canonical_path = ["/categories", root, sub].compact.join("/")
    @page_title = @path_names.join(" - ") unless @path_names.empty?
    @page_description = Indexer.category_definition(@path_names.last)
    render
  end
end
