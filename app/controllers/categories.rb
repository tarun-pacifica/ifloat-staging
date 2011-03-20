class Categories < Application
  def show(root = nil, sub = nil)
    path_names = [root, sub].compact.map { |name| name.tr("+", " ") }
    # @links = path_names.length.times.map { |i| category_link(path_names[0, i + 1]) }
    
    children = Indexer.category_children_for_node(path_names)
    if children.empty?
      return render("../cached_finds/new".to_sym, :status => 404)
    elsif children.first.is_a?(Integer)
      product_links_by_node, @product_ids = marshal_product_links(:products => children)
      @product_links = product_links_by_node[:products]
    else
      @children_links = children.map { |child| category_link(path_names + [child]) }.sort
    end
    
    # @definitions = path_names.map do |name|
    #   definition = Indexer.category_definition(name)
    #   definition.nil? ? nil : [name, definition]
    # end.compact
    
    @canonical_path = ["/categories", root, sub].compact.join("/")
    @page_title = (path_names.empty? ? "All categories" : path_names.join(" - "))
    @page_description = Indexer.category_definition(path_names.last)
    @page_description ||= "The ifloat® yachting/sailing/boating categories provide a traditional way to see all the the marine leisure nautical products we have." if root.nil?
    render
  end
end
