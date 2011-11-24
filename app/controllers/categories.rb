class Categories < Application
  def filter(root, sub, id)
    provides :js
    headers["Cache-Control"] = "max-age=0"
    
    path_names, product_ids = path_names_and_children(root, sub, found_product_ids)
    filter_detail(id.to_i, filtered_product_ids(product_ids)).to_json
  end
  
  def filters(root, sub)
    provides :js
    headers["Cache-Control"] = "max-age=0"
    
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
      if @find_phrase.blank? or path_names_and_children(root, sub, nil).last.empty?
        redirection = redirection_for(@path_names)
        return redirection.nil? ? categories_404 : redirect(redirection, :status => 301)
      end
      
      @find_alternatives = find_phrase_alternatives(@find_phrase)
      @find_bad = true
    end
    
    @child_links =
      if children.first.is_a?(Integer)
        product_links_by_node, @product_ids = marshal_product_links(:products => children)
        product_links_by_node[:products]
      else
        children.map { |child| category_link(@path_names + [child]) }
      end
    
    @canonical_path = ["/categories", root, sub].compact.join("/")
    @page_title = @path_names.join(" - ") unless @path_names.empty?
    @page_description = Indexer.category_definition_for_node(@path_names)
    @page_description ||= "Find and buy boat equipment, accessories, sailing clothing and sea books and charts." if @path_names.empty?
    render
  end
  
  
  private
  
  def filter_detail(property_id, product_ids)
    prop_info = Indexer.property_display_cache[property_id]
    return [] if prop_info.nil? or product_ids.empty?
    
    values = Indexer.filterable_values_for_property_id(property_id, product_ids, session.language)
    
    if prop_info[:type] == "text"
      defs_by_value = (PropertyValueDefinition.by_property_id([property_id], session.language)[property_id] || {})
      prop_info.merge(:values => values.zip(defs_by_value.values_at(*values)))
      
    else
      klass = PropertyType.value_class(prop_info[:type])
      formatted = values.map do |units_with_values|
        units_with_values.map { |u, v| klass.format(v, v, nil, u, :verbose => true) }.join(" / ")
      end
      prop_info.merge(:values => values.zip(formatted))
      
    end
  end
  
  def filtered_product_ids(product_ids)
    filters = (JSON.parse(params["filters"]) rescue [])
    (filters.empty? ? product_ids : Indexer.product_ids_for_filters(product_ids, filters, session.language))
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
  
  # TODO: remove once redirects no longer required
  def build_redirects
    redirects = {}
    FasterCSV.foreach(Merb.root / "config" / "category_redirects.csv", :encoding => "UTF-8") do |row|
      old_path_names, new_path_names = row[0, 2].map { |f| f.split("/") }
      redirects[old_path_names] = category_url(new_path_names)
    end
    redirects
  end
  
  # TODO: remove once redirects no longer required
  def redirection_for(path_names)
    (@@redirects ||= build_redirects)[path_names]
  end
end
