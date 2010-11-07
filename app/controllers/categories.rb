class Categories < Application
  def show(root = nil, suba = nil, subb = nil)
    path_names = [root, suba, subb].compact.map { |name| name.tr("+", " ") }
    @links = path_names.length.times.map { |i| category_link(path_names[0, i + 1]) }
    
    children = Indexer.category_children_for_node(path_names)
    @children_links = children.map do |child|
      if child.is_a?(String) then category_link(path_names + [child])
      else "<a href=#{Indexer.product_url(child).inspect}>#{Indexer.product_title(:canonical, child).superscript}</a>"
      end
    end
    
    @showing_products = children.first.is_a?(Integer)
    children.empty? ? render("../cached_finds/new".to_sym, :status => 404) : render
  end
end
