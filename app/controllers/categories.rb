class Categories < Application
  def filter(root, sub, id, filters)
    provides :js    
    path_names, product_ids = path_names_and_children(root, sub)
    filter_detail(id.to_i, product_ids, filters).to_json
  end
  
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
  
  def filter_detail(property_id, product_ids, filters)
    prop_info = Indexer.property_display_cache[property_id]
    return [] if prop_info.nil? or product_ids.empty?
    
    definitions = (PropertyValueDefinition.by_property_id([property_id], session.language)[property_id] || {})
    type = prop_info[:type]
    value_class = PropertyType.value_class(type)
    
    pids = filtered_product_ids(product_ids, filters)
    values_by_unit = {}
    Indexer.filterable_values_for_property_id(property_id, pids, pids, session.language).each do |unit, values|
      all_values, relevant_values = values
      extra_values = 
        if type == "text" then all_values.map { |v| definitions[v] }
        else all_values.map { |v| value_class.format(v, v, nil, unit, :verbose => true) }
        end
      values_by_unit[unit] = all_values.zip(extra_values)
    end
    
    prop_info.merge(:values_by_unit => values_by_unit)
  end
  
  def filtered_product_ids(product_ids, filters)
    filters = (JSON.parse(filters) rescue {})
    product_ids # TODO: do filtering
  end
  
  def path_names_and_children(root, sub)
    path_names = [root, sub].compact.map { |name| name.tr("+", " ") }
    [path_names, Indexer.category_children_for_node(path_names)]
  end
end
