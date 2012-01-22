module Indexer
  COMPILED_PATH = (Merb.env == "test" ? "caches/indexer.test.marshal" : "caches/indexer.marshal" )
  SITEMAP_PATH = "public/sitemap.xml"
  
  @@auto_diff_property_id = nil
  @@banner_html_by_location = nil
  @@brand_property_id = nil
  @@category_definitions = {}
  @@category_image_urls = {}
  @@category_tree = {}
  @@class_property_id = nil
  @@facility_cache = {}
  @@image_checksum_index = {}
  @@last_loaded_lock = Mutex.new
  @@last_loaded_md5 = nil
  @@last_loaded_time = nil
  @@max_product_id = nil
  @@numeric_filtering_index = {}
  @@product_relationship_cache = {}
  @@product_title_cache = {}
  @@property_display_cache = {}
  @@sale_price_min_property_id = nil
  @@spellers = {}
  @@text_filtering_index = {}
  @@text_finding_index = {}
  
  def self.auto_diff_property_id
    @@auto_diff_property_id if ensure_loaded
  end
  
  def self.autocomplete(phrase, language_code)
    return [] unless ensure_loaded
    
    words = normalized_find_words(phrase)
    w = words.pop
    
    found_product_ids = nil
    found_product_ids = product_ids_for_phrase(words.join(" "), language_code) unless words.empty?
    
    index = (@@text_finding_index[language_code] || {})
    matches = index.select do |word, product_ids|
      word[0, w.size] == w and (found_product_ids.nil? ? true : (not (found_product_ids & product_ids).empty?))
    end
    
    weighted_matches = matches.sort_by { |word, product_ids| -product_ids.size }
    weighted_matches.map { |match, product_ids| (words + [match]).join(" ") }
  end
  
  def self.banner_html_for_location(location)
    (@@banner_html_by_location[location] || []).choice if ensure_loaded
  end
  
  def self.brand_property_id
    @@brand_property_id if ensure_loaded
  end
  
  def self.category_children_for_node(path_names, only_product_ids = nil)
    return [] unless ensure_loaded
    
    node = path_names.inject(@@category_tree) do |node, name|
      if (node.is_a?(Hash) and node.has_key?(name)) then node[name]
      else return []
      end
    end
    
    return (node.is_a?(Hash) ? node.keys : node).compact if only_product_ids.nil?
    
    return (only_product_ids & node).to_a if node.is_a?(Array)
    
    integer_collector = proc { |node| node.is_a?(Array) ? node : node.values.map(&integer_collector) }
    node.map do |key, children|
      key unless (only_product_ids & integer_collector.call(children).flatten).empty?
    end.compact
  end
  
  def self.category_definition_for_node(path_names)
    return nil unless ensure_loaded
    
    children = (category_children_for_node(path_names) || []).sort
    definition = @@category_definitions[path_names.last]
    return definition if children.empty?
    
    # category_statement =
      # case path_names.size
      # when 0 then "Categories include: #{children.friendly_join('and')}."
      # when 1 then "Product types include: #{children.friendly_join('and')}."
      # else return definition
      # end
    
    # [definition, category_statement].compact.join(" ")
    
    definition
  end
  
  def self.category_image_url_for_node(path_names)
    return nil unless ensure_loaded
    stem = path_names.last.to_s.downcase.tr(" ", "_")
    @@category_image_urls[stem]
  end
  
  def self.class_property_id
    @@class_property_id if ensure_loaded
  end
  
  def self.compile
    Tempfile.open(File.basename(COMPILED_PATH)) do |f|
      properties = PropertyDefinition.all
      records = text_records
      
      indexes = {
        :banner_html_by_location    => compile_banner_html_by_location,
        :category_definitions       => compile_category_definitions(properties, records),
        :category_image_urls        => compile_category_image_urls,
        :category_tree              => compile_category_tree(properties, records),
        :facility_cache             => compile_facility_cache,
        :image_checksums            => compile_image_checksum_index,
        :numeric_filtering          => compile_numeric_filtering_index,
        :product_relationship_cache => ProductRelationship.compile_index,
        :product_title_cache        => compile_product_title_cache,
        :property_display_cache     => compile_property_display_cache(properties),
        :text_filtering             => compile_text_filtering_index(records.select { |r| r.filterable }),
        :text_finding               => compile_text_finding_index(properties, records)
      }
      
      FileUtils.mkpath(File.dirname(COMPILED_PATH))
      f.write Marshal.dump(indexes)
      File.delete(COMPILED_PATH) if File.exists?(COMPILED_PATH)
      File.link(f.path, COMPILED_PATH)
    end
  end
  
  def self.correct_spelling(word, language_code)
    return nil unless ensure_loaded and @@spellers.has_key?(language_code)
    @@spellers[language_code].correct(word)
  end
  
  def self.ensure_loaded
    @@last_loaded_lock.synchronize do
      begin
        load if @@last_loaded_time.nil? or @@last_loaded_time + 15 < Time.now
        true
      rescue
        false
      end
    end
  end
  
  def self.facilities
    @@facility_cache if ensure_loaded
  end
  
  def self.filterable_values_for_property_id(property_id, product_ids, language_code)
    return [] if product_ids.empty? or not ensure_loaded
    
    property_info = @@property_display_cache[property_id]
    return [] if property_info.nil?
    
    if property_info[:type] == "text"
      values_by_prod_id_by_prop_id = @@text_filtering_index[language_code]
      return [] if values_by_prod_id_by_prop_id.nil?
      values_by_prod_id = values_by_prod_id_by_prop_id[property_id]
      return [] if values_by_prod_id_by_prop_id.nil?
      values_by_prod_id.values_at(*product_ids).compact.flatten.uniq.sort
      
    else
      values_by_unit_by_seq_by_prod_id = @@numeric_filtering_index[property_id]
      return [] if values_by_unit_by_seq_by_prod_id.nil?
      all_expanded_values = []
      values_by_unit_by_seq_by_prod_id.values_at(*product_ids).compact.map(&:values).flatten.each do |values_by_unit|
        expanded_values = []
        values_by_unit.each do |unit, value|
          (value.is_a?(Range) ? [value.first, value.last] : [value]).each_with_index do |v, i|
            (expanded_values[i] ||= {})[unit.to_s] = v
          end
        end
        all_expanded_values += expanded_values.map(&:sort)
      end
      all_expanded_values.uniq.sort
      
    end
  end
  
  def self.image_checksums_for_product_ids(product_ids)
    return {} if product_ids.empty? or not ensure_loaded
    product_ids.group_by { |id| @@image_checksum_index[id] }
  end
  
  def self.last_loaded_md5
    @@last_loaded_md5
  end
  
  def self.load
    raise "no such file: #{COMPILED_PATH}" unless File.exists?(COMPILED_PATH)
    raise "file unreadable: #{COMPILED_PATH}" unless File.readable?(COMPILED_PATH)
    
    source_md5 = Digest::MD5.file(COMPILED_PATH).hexdigest
    if source_md5 == @@last_loaded_md5
      @@last_loaded_time = Time.now
      return
    end
    
    File.open(COMPILED_PATH) do |f|
      indexes = Marshal.load(f)
      @@banner_html_by_location    = indexes[:banner_html_by_location]
      @@category_definitions       = indexes[:category_definitions]
      @@category_image_urls        = indexes[:category_image_urls]
      @@category_tree              = indexes[:category_tree]
      @@facility_cache             = indexes[:facility_cache]
      @@image_checksum_index       = indexes[:image_checksums]
      @@numeric_filtering_index    = indexes[:numeric_filtering]
      @@product_ids_by_checksum    = nil
      @@product_relationship_cache = indexes[:product_relationship_cache]
      @@product_title_cache        = indexes[:product_title_cache]
      @@property_display_cache     = indexes[:property_display_cache]
      @@text_filtering_index       = indexes[:text_filtering]
      @@text_finding_index         = indexes[:text_finding]
    end
    
    @@auto_diff_property_id = PropertyDefinition.first(:name => "auto:group_diff").id
    @@brand_property_id = PropertyDefinition.first(:name => "marketing:brand").id
    @@class_property_id = PropertyDefinition.first(:name => "reference:class").id
    @@max_product_id = repository.adapter.select("SELECT max(id) FROM products").first
    @@sale_price_min_property_id = PropertyDefinition.first(:name => "sale:price_min").id
    
    # TODO: this needs to be done by one thread only - at init (if not in console mode) and then as a background thread
    #       or possibly from the Importer housekeeping actions
    assets_by_checksum = Asset.all(:bucket => "products").hash_by(:checksum)
    File.open(SITEMAP_PATH, "w") do |f|
      f.puts '<?xml version="1.0" encoding="UTF-8"?>'
      f.puts '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">'
      urls = (@@product_title_cache[:url] || {}).map do |product_id, stem|
        parts = ["<url>"]
        parts << "<loc>http://www.ifloat.biz#{stem}</loc>"
        parts << "<changefreq>daily</changefreq>"
        
        image = assets_by_checksum[@@image_checksum_index[product_id]]
        parts << "<image:image>"
        parts << "<image:loc>#{image.url}</image:loc>"
        parts << "<image:title>#{image.name}</image:title>"
        parts << "</image:image>"
        
        parts << "</url>"
        parts.join(" ")
      end
      f.puts urls
      f.puts '</urlset>'
    end
    
    # TODO: we may need bespoke alphabets per language
    alphabet = ('a'..'z').to_a + ('0'..'9').to_a + %w(')
    @@text_finding_index.each do |language_code, index|
      frequencies_by_words = Hash[index.map { |word, prod_ids| [word, prod_ids.size] }]
      @@spellers[language_code] = Speller.new(frequencies_by_words, alphabet)
    end
    
    @@last_loaded_md5 = source_md5
    @@last_loaded_time = Time.now
  end
  
  def self.max_product_id
    @@max_product_id if ensure_loaded
  end
  
  def self.product_ids_for_filters(product_ids, filters, language_code)
    return [] unless ensure_loaded
    
    prod_id_sets = filters.map do |filter|
      property_id, *values = filter
      prop_info = @@property_display_cache[property_id]
      next if prop_info.nil?
      
      if (prop_info[:type] == "text")
        filter_value = values.first
        values_by_prod_id = ((@@text_filtering_index[language_code] || {})[property_id] || {})
        product_ids.select { |prod_id| (values_by_prod_id[prod_id] || []).include?(filter_value) }
        
      else
        fu1, fv1, fu2, fv2 = values.map(&:first).flatten
        return [] unless fu1 == fu2 and fv1 <= fv2 # bomb out as filter invalid
        fu1 = nil if fu1.blank?
        values_by_unit_by_seq_by_prod_id = (@@numeric_filtering_index[property_id] || {})
        product_ids.select do |prod_id|
          (values_by_unit_by_seq_by_prod_id[prod_id] || {}).any? do |seq, values_by_unit|
            v = values_by_unit[fu1]
            next if v.nil?
            v1, v2 = (v.is_a?(Range) ? [v.first, v.last] : [v, v])
            v2 >= fv1 and v1 <= fv2
          end
        end
        
      end
    end.compact
    
    prod_id_sets.empty? ? [] : prod_id_sets.inject { |union, ids| union & ids }
  end
  
  def self.product_ids_for_image_checksum(checksum)
    return nil unless ensure_loaded
    (@@product_ids_by_checksum ||= @@image_checksum_index.keys.group_by { |id| @@image_checksum_index[id] })[checksum]
  end
  
  def self.product_ids_for_phrase(phrase, language_code)
    return [] if phrase.blank? or not ensure_loaded
    
    index = (@@text_finding_index[language_code] || {})
    normalized_find_words(phrase).map do |word|
       (index[word] || Set.new).to_set
    end.inject { |union, product_ids| union & product_ids }
  end
  
  def self.product_relationships(product_id)
    @@product_relationship_cache[product_id] if ensure_loaded
  end
  
  # TODO: support language code
  def self.product_title(domain, product_id)
    (@@product_title_cache[domain] || {})[product_id] if ensure_loaded
  end
  
  def self.product_url(product_id)
    product_title(:url, product_id)
  end
  
  # TODO: extend to support multiple languages
  def self.property_display_cache
    return {} unless ensure_loaded
    @@property_display_cache
  end
  
  def self.property_ids_for_product_ids(product_ids, language_code)
    return [] if product_ids.empty? or not ensure_loaded
    
    product_ids = product_ids.to_set
    property_ids = []
    
    each_filtering_index(language_code) do |prop_id, things_by_prod_id|
      matching_product_ids = (product_ids & things_by_prod_id.keys)
      next if matching_product_ids.empty?
      property_ids << prop_id and next if matching_product_ids.size < product_ids.size
      property_ids << prop_id unless things_by_prod_id.values_at(*product_ids).uniq.size == 1
    end
    
    property_ids.to_set
  end
  
  def self.sale_price_min_property_id
    @@sale_price_min_property_id if ensure_loaded
  end
  
  
  private
  
  def self.compile_banner_html_by_location
    Hash[ Banner.all.group_by(&:location).map { |location, banners| [location, banners.map(&:html)] } ]
  end
  
  # TODO: extend to support multiple languages
  def self.compile_category_definitions(properties, records)
    property_names = %w(reference:category reference:class marketing:brand)
    property_ids = properties.select { |pd| property_names.include?(pd.name) }.sort_by { |pd| property_names.index(pd.name) }.map { |pd| pd.id }
    
    defs_by_value_by_prop_id = PropertyValueDefinition.by_property_id(property_ids[0, 2], "ENG")
    defs_by_value = defs_by_value_by_prop_id.values.inject(:update)
    
    # TODO: evaluate alternatives as these lists end up being too long in practice
    # values_by_prod_id_by_prop_id = {}
    # records.each do |record|
    #   next unless property_ids.include?(record.property_definition_id)
    #   values_by_prod_id = (values_by_prod_id_by_prop_id[record.property_definition_id] ||= {})
    #   values_by_prod_id[record.product_id] = record.text_value
    # end
    # 
    # brands_by_prod_id = values_by_prod_id_by_prop_id.delete(property_ids.last)
    # prod_ids_by_value = {}
    # values_by_prod_id_by_prop_id.each do |prop_id, values_by_prod_id|
    #   values_by_prod_id.each do |prod_id, value|
    #     (prod_ids_by_value[value] ||= []) << prod_id
    #   end
    # end
    # 
    # branded_defs_by_value = {}
    # (defs_by_value.keys | prod_ids_by_value.keys).each do |value|
    #   brands = brands_by_prod_id.values_at(*prod_ids_by_value[value]).compact.uniq.sort
    #   brand_statement = (brands.empty? ? nil : "Brands include: #{brands.friendly_join('and')}.")
    #   branded_defs_by_value[value] = [defs_by_value[value], brand_statement].compact.join(" ")
    # end
    # branded_defs_by_value
  end
  
  def self.compile_category_image_urls()
    Hash[Asset.all(:bucket => "category_images").map { |a| [a.name =~ Asset::NAME_FORMAT ? $1 : nil, a.url] }]
  end
  
  def self.compile_category_tree(properties, records)
    property_names = %w(reference:category reference:class)
    properties = properties.select { |pd| property_names.include?(pd.name) }
    properties_by_id = properties.hash_by(:id)
    properties_by_name = properties.hash_by(:name)
    
    values_by_prop_id_by_prod_id = {}
    records.each do |record|
      next unless properties_by_id.has_key?(record.property_definition_id)
      values_by_prop_id = (values_by_prop_id_by_prod_id[record.product_id] ||= {})
      values_by_prop_id[record.property_definition_id] = record.text_value
    end
    
    tree = {}
    values_by_prop_id_by_prod_id.each do |prod_id, values_by_prop_id|
      node = tree
      
      property_names[0..-2].each do |prop_name|
        prop_id = properties_by_name[prop_name].id
        prod_value = values_by_prop_id[prop_id]
        node = (node[prod_value] ||= {})
      end
      
      prop_id = properties_by_name[property_names[-1]].id
      prod_value = values_by_prop_id[prop_id]
      (node[prod_value] ||= []) << prod_id
    end
    
    tree
  end
  
  def self.compile_facility_cache
    facility_info_by_url = {}
    Facility.all.each do |facility|
      facility_info_by_url[facility.primary_url] = facility.attributes
    end
    facility_info_by_url
  end
    
  def self.compile_image_checksum_index
    query =<<-SQL
      SELECT p.id, a.checksum
      FROM products p
        INNER JOIN attachments at ON p.id = at.product_id
        INNER JOIN assets a ON at.asset_id = a.id
      WHERE at.role = 'image'
      ORDER BY at.sequence_number
    SQL
    
    index = {}
    repository.adapter.select(query).each do |record|
      index[record.id] ||= record.checksum
    end
    index
  end
  
  def self.compile_numeric_filtering_index
    query =<<-SQL
      SELECT pv.product_id, pv.property_definition_id, pv.unit, pv.min_value, pv.max_value, pv.sequence_number
      FROM property_values pv
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
      WHERE pd.filterable = ?
        AND (pv.min_value IS NOT NULL OR pv.max_value IS NOT NULL)
    SQL
    
    values_by_unit_by_seq_by_prod_id_by_prop_id = {}
    repository.adapter.select(query, true).each do |record|
      values = [record.min_value, record.max_value].uniq.map { |v| v.to_f }
      value = (values.size == 1 ? values.first : Range.new(*values))
      
      values_by_unit_seq_by_prod_id =
        (values_by_unit_by_seq_by_prod_id_by_prop_id[record.property_definition_id] ||= {})
      values_by_unit_by_seq = (values_by_unit_seq_by_prod_id[record.product_id] ||= {})
      values_by_unit = (values_by_unit_by_seq[record.sequence_number] ||= {})
      values_by_unit[record.unit] = value
    end
    values_by_unit_by_seq_by_prod_id_by_prop_id
  end
  
  def self.compile_product_title_cache
    query =<<-SQL
      SELECT product_id, property_definition_id, text_value, sequence_number
      FROM property_values
      WHERE property_definition_id IN ?
        AND language_code = 'ENG'
        AND text_value IS NOT NULL
    SQL
    
    property_names = %w(auto:title marketing:summary)
    properties = PropertyDefinition.all(:name => property_names)
    return {} unless properties.size == property_names.size
    
    summary_prop_id = properties.find { |prop| prop.name == "marketing:summary" }.id
    domains = [:summary, :canonical, :description, :image]
    
    values_by_product_id_by_domain = {}
    repository.adapter.select(query, properties.map { |prop| prop.id }).each do |record|
      seq_num = (record.property_definition_id == summary_prop_id ? 0 : record.sequence_number)
      domain = domains[seq_num]
      insertions = {domain => record.text_value}
      
      if domain == :canonical
        simplified = record.text_value.desuperscript.downcase.delete("'").gsub(/[^a-z0-9\.]+/, "-")[0, 250]
        insertions[:url] = "/products/#{simplified}-#{record.product_id}"
      end
      
      insertions.each do |domain, value|
        values_by_product_id = (values_by_product_id_by_domain[domain] ||= {})
        values_by_product_id[record.product_id] = value
      end
    end
    values_by_product_id_by_domain
  end
  
  # TODO: extend to support other languages
  def self.compile_property_display_cache(properties)
    friendly_names = PropertyDefinition.friendly_name_sections(properties, "ENG")
    
    icon_urls = {}
    properties_by_asset_name = Hash[ properties.map { |property| [property.name.tr(":", "_") + ".png", property] } ]
    Asset.all(:bucket => "property_icons").each do |asset|
      if asset.name == "blank.png"
        icon_urls.default = asset.url
      else 
        property = properties_by_asset_name[asset.name]
        icon_urls[property.id] = asset.url unless property.nil?
      end
    end
    
    cache = {}
    properties.each do |property|
      section, name = friendly_names[property.id]
      cache[property.id] = {
        :id       => property.id,
        :section  => section,
        :name     => name,
        :icon_url => icon_urls[property.id],
        :type     => property.property_type.core_type,
        # internal
        :seq_num  => property.sequence_number,
        :dad      => property.display_as_data?,
        :fil      => property.filterable?,
        :raw_name => property.name
      }
    end
    cache
  end
  
  def self.compile_text_filtering_index(records)
    values_by_prod_id_by_prop_id_by_lang = {}
    
    records.each do |record|
      values_by_prod_id_by_prop_id = (values_by_prod_id_by_prop_id_by_lang[record.language_code] ||= {})
      values_by_prod_id = (values_by_prod_id_by_prop_id[record.property_definition_id] ||= {})
      (values_by_prod_id[record.product_id] ||= []) << record.text_value
    end
    
    values_by_prod_id_by_prop_id_by_lang.each do |lang, values_by_prod_id_by_prop_id|
      values_by_prod_id_by_prop_id.each do |prop_id, values_by_prod_id|
        values_by_prod_id.each { |prod_id, values| values.uniq! }
      end
    end
    
    values_by_prod_id_by_prop_id_by_lang
  end
  
  def self.compile_text_finding_index(properties, records)
    index = {}
    prod_ids_by_values_by_prop_ids = {}
    
    records.each do |record|
      prod_ids_by_values = (prod_ids_by_values_by_prop_ids[record.property_definition_id] ||= {})
      (prod_ids_by_values[record.text_value] ||= []) << record.product_id
      
      next unless record.findable
      
      normalized_find_words(record.text_value).each do |word|
        language = (index[record.language_code] ||= {})
        (language[word] ||= []) << record.product_id
      end
    end
    
    # TODO: contemplate how to make associated words multilingual
    eng_index = (index["ENG"] ||= {})
    properties_by_name = properties.hash_by(:name)
    AssociatedWord.all.each do |aword|
      word = normalized_find_words(aword.word).first
      eng_index[word] = (eng_index[word] || []) + aword.rules.map do |property_name, value|
        prop_id = properties_by_name[property_name].id
        (prod_ids_by_values_by_prop_ids[prop_id] || {})[value] || []
      end.inject { |union, product_ids| union & product_ids }
    end
    
    index.each do |language, words|
      words.each { |word, product_ids| product_ids.uniq! }
    end
    index
  end
  
  def self.each_filtering_index(language_code, &block)
    @@numeric_filtering_index.each(&block)
    (@@text_filtering_index[language_code] || {}).each(&block)
  end
  
  def self.normalized_find_words(phrase)
    phrase.delete("'-").downcase.split(/[^a-z0-9]+/).uniq
  end
  
  def self.text_records
    query =<<-SQL
      SELECT pd.findable, pd.filterable, pv.product_id, pv.property_definition_id, pv.language_code, pv.text_value
      FROM property_values pv
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
      WHERE pv.text_value IS NOT NULL
    SQL
    
    repository.adapter.select(query)
  end
end