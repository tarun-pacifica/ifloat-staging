class Categories < Application
  def filter(root, sub, id)
    provides :js    
    path_names, product_ids = path_names_and_children(root, sub, found_product_ids)
    filter_detail(id.to_i, filtered_product_ids(product_ids)).to_json
  end
  
  def filters(root, sub)
    provides :js
    
    path_names, product_ids = path_names_and_children(root, sub, found_product_ids)
    return [].to_json if product_ids.empty?
    
    property_ids = Indexer.property_ids_for_product_ids(filtered_product_ids(product_ids), session.language)
    
    filters = (JSON.parse(params["filters"]) rescue [])
    filter_ids = filters.map { |f| f.first }.to_set
    property_ids = property_ids.reject { |id| filter_ids.include?(id) }
    
    Indexer.property_display_cache.values_at(*property_ids).compact.sort_by { |info| info[:seq_num] }.to_json
  end
  
  def show(root = nil, sub = nil)
    @find_phrase = params["find"]
    fpids = found_product_ids
    @path_names, children = path_names_and_children(root, sub, fpids)
    
    children = filtered_product_ids(children) if children.first.is_a?(Integer)
    
    if children.empty?
      return categories_404 if @find_phrase.blank? or path_names_and_children(root, sub, nil).last.empty?
      @find_alternatives = find_phrase_alternatives(@find_phrase)
      @find_bad = true
    end
    
    child_paths = children.map { |child| @path_names + [child] }
    
    @child_links =
      if children.first.is_a?(Integer)
        product_links_by_node, @product_ids = marshal_product_links(:products => children)
        product_links_by_node[:products]
      else
        child_paths.map { |path| category_link(path) }
      end
    
    @child_link_image_urls = child_paths.map { |path| Indexer.category_image_url_for_node(path) } if @path_names.size == 1
    
    @canonical_path = ["/categories", root, sub].compact.join("/")
    @page_title = @path_names.join(" - ") unless @path_names.empty?
    @page_description = Indexer.category_definition_for_node(@path_names)
    render
  end
  
  
  private
  
  def filter_detail(property_id, product_ids)
    prop_info = Indexer.property_display_cache[property_id]
    return [] if prop_info.nil? or product_ids.empty?
    
    definitions = (PropertyValueDefinition.by_property_id([property_id], session.language)[property_id] || {})
    type = prop_info[:type]
    value_class = PropertyType.value_class(type)
    
    values_by_unit = {}
    Indexer.filterable_values_for_property_id(property_id, product_ids, session.language).each do |unit, values|
      extra_values =
        if type == "text" then values.map { |v| definitions[v] }
        else values.map do |value|
            v1, v2 = (value.is_a?(Range) ? [value.first, value.last] : [value, value])
            value_class.format(v1, v2, RANGE_SEPARATOR, unit, :verbose => true)
          end
        end
      values_by_unit[unit] = values.zip(extra_values)
    end
    
    prop_info.merge(:values_by_unit => values_by_unit)
  end
  
  def filtered_product_ids(product_ids)
    filters = (JSON.parse(params["filters"]) rescue [])
    (filters.empty? ? product_ids : Indexer.product_ids_for_filters(product_ids, filters))
  end
  
  def find_phrase_alternatives(phrase)
    words = phrase.downcase.split.map { |word| Indexer.correct_spelling(word, session.language) }.compact
    return words if words.size <= 1
    
    words.size.downto(1) do |i|
      hits = words.combination(i).map do |combo|
        spec = combo.join(" ")
        (Indexer.product_ids_for_phrase(spec, session.language).size > 0) ? spec : nil
      end.compact
      return hits unless hits.empty?
    end
    
    []
  end
  
  def found_product_ids
    phrase = params["find"]
    phrase.nil? ? nil : Indexer.product_ids_for_phrase(phrase, session.language)
  end
  
  def path_names_and_children(root, sub, only_product_ids)
    path_names = [root, sub].compact.map { |name| name.tr("+", " ") }
    [path_names, Indexer.category_children_for_node(path_names, only_product_ids).sort]
  end
end
