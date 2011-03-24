class Categories < Application
  def filter(root, sub, id)
    provides :js    
    path_names, product_ids = path_names_and_children(root, sub)
    filter_detail(id.to_i, filtered_product_ids(product_ids)).to_json
  end
  
  def filters(root, sub)
    provides :js
    
    path_names, product_ids = path_names_and_children(root, sub)
    return [].to_json if product_ids.empty?
    
    property_ids = Indexer.property_ids_for_product_ids(filtered_product_ids(product_ids), session.language)
    
    filters = (JSON.parse(params["filters"]) rescue [])
    filter_ids = filters.map { |f| f.first }.to_set
    property_ids = property_ids.reject { |id| filter_ids.include?(id) }
    
    Indexer.property_display_cache.values_at(*property_ids).compact.sort_by { |info| info[:seq_num] }.to_json
  end
  
  def show(root = nil, sub = nil)
    @find_phrase = params["find"]
    @path_names, children = path_names_and_children(root, sub)
    
    children = filtered_product_ids(children) if children.first.is_a?(Integer)
    
    if children.empty?
      return categories_404 if @find_phrase.blank? or path_names_and_children(root, sub, nil).last.empty?
      @find_alternatives = find_phrase_alternatives(@find_phrase)
      @find_bad = true
    end
    
    @child_links =
      if children.first.is_a?(Integer)
        product_links_by_node, @product_ids = marshal_product_links(:products => children)
        product_links_by_node[:products]
      else
        children.map { |child| category_link(@path_names + [child]) }.sort
      end
    
    if @path_names.size == 1
      first_product_ids = children.sort.map { |child| Indexer.category_children_for_node(@path_names + [child]).first }
      
      checksums_by_product_id = {}
      Indexer.image_checksums_for_product_ids(first_product_ids).each do |checksum, product_ids|
        product_ids.each { |product_id| checksums_by_product_id[product_id] = checksum }
      end
      
      assets_by_checksum = Asset.all(:checksum => checksums_by_product_id.values.uniq).hash_by(:checksum)
      
      @child_link_background_urls = first_product_ids.map do |product_id|
        assets_by_checksum[checksums_by_product_id[product_id]].url(:tiny)
      end
    end
    
    @canonical_path = ["/categories", root, sub].compact.join("/")
    @page_title = @path_names.join(" - ") unless @path_names.empty?
    @page_description = Indexer.category_definition(@path_names.last)
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
    filters.empty? ? product_ids : Indexer.product_ids_for_filters(product_ids, filters)
  end
  
  def find_phrase_alternatives(phrase)
    words = phrase.downcase.split.map { |word| Indexer.correct_spelling(word, session.language) }.compact
    return words if words.size <= 1
    
    (words.size - 1).downto(1) do |i|
      hits = words.combination(i).map do |combo|
        spec = combo.join(" ")
        (Indexer.product_ids_for_phrase(spec, session.language).size > 0) ? spec : nil
      end.compact
      return hits unless hits.empty?
    end
    
    []
  end
  
  def path_names_and_children(root, sub, find_phrase = params["find"])
    path_names = [root, sub].compact.map { |name| name.tr("+", " ") }
    only_product_ids = nil
    only_product_ids = Indexer.product_ids_for_phrase(find_phrase, session.language) unless find_phrase.nil?
    [path_names, Indexer.category_children_for_node(path_names, only_product_ids)]
  end
end
