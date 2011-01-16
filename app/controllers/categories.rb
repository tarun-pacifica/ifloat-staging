class Categories < Application
  def show(root = nil, suba = nil, subb = nil)
    path_names = [root, suba, subb].compact.map { |name| name.tr("+", " ") }
    @links = path_names.length.times.map { |i| category_link(path_names[0, i + 1]) }
    
    children = Indexer.category_children_for_node(path_names)
    @children_links = children.map do |child|
      if child.is_a?(String) then category_link(path_names + [child])
      else "<a href=#{Indexer.product_url(child).inspect}>#{Indexer.product_title(:canonical, child).superscript}</a>"
      end
    end.sort
    
    @definitions = path_names.map do |name|
      definition = Indexer.category_definition(name)
      definition.nil? ? nil : [name, definition]
    end.compact
    
    @showing_products = children.first.is_a?(Integer)
    
    if children.empty?
      render("../cached_finds/new".to_sym, :status => 404)
    else
      @page_title = (path_names.empty? ? "All categories" : path_names.join(" - "))
      @page_description = Indexer.category_definition(path_names.last)
      @page_description ||= "The ifloat® yachting/sailing/boating categories provide a traditional way to see all the the marine leisure nautical products we have." if root.nil?
      render
    end
  end
end
