class Categories < Application
  def filters(root, sub, filters)
    provides :js
    
    path_names, product_ids = path_names_and_children(root, sub)
    return {}.to_json if product_ids.empty?
    
    filters = (JSON.parse(filters) rescue {})
    property_ids = Indexer.property_ids_for_product_ids(product_ids, session.language).reject { |id| filters.has_key?(id) }
    Indexer.property_display_cache.values_at(*property_ids).compact.sort_by { |info| info[:seq_num] }.to_json
  end
  
  def show(root = nil, sub = nil)
    @path_names, children = path_names_and_children(root, sub)
    
    return render("../cached_finds/new".to_sym, :status => 404) if children.empty?
    
    if children.first.is_a?(Integer)
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
  
  
  private
  
  def path_names_and_children(root, sub)
    path_names = [root, sub].compact.map { |name| name.tr("+", " ") }
    [path_names, Indexer.category_children_for_node(path_names)]
  end
end
