module Indexer
  COMPILED_PATH = "caches/indexer.marshal"
  SITEMAP_PATH = "public/sitemap.xml"
  
  @@category_tree = {}
  @@class_property_id = nil
  @@image_checksum_index = {}
  @@last_loaded_md5 = nil
  @@numeric_filtering_index = {}
  @@product_url_cache = {}
  @@property_display_cache = {}
  @@sale_price_min_property_id = nil
  @@skip_load = false
  @@tag_index = {}
  @@tag_frequencies = nil
  @@text_filtering_index = {}
  @@text_finding_index = {}
  
  def self.category_children_for_node(path_names = [])
    return [] unless ensure_loaded
    return @@category_tree.keys.sort if path_names.empty?
    
    node = @@category_tree
    while path_names.any?
      node = node[path_names.shift]
      return [] if node.nil?
    end
    node.is_a?(Hash) ? node.keys : node
  end
  
  def self.class_property_id
    @@class_property_id if ensure_loaded
  end
  
  def self.compile
    Tempfile.open(File.basename(COMPILED_PATH)) do |f|
      properties = PropertyDefinition.all
      records = text_records
      
      indexes = {
        :category_tree           => compile_category_tree(properties, records),
        :image_checksums         => compile_image_checksum_index,
        :numeric_filtering       => compile_numeric_filtering_index,
        :product_url_cache       => compile_product_url_cache,
        :property_display_cache  => compile_property_display_cache(properties),
        :tag_index               => compile_tag_index(properties, records),
        :text_filtering          => compile_filtering_index(records.select { |r| r.filterable }, :language_code, :text_value),
        :text_finding            => compile_text_finding_index(properties, records)
      }
      
      FileUtils.mkpath(File.dirname(COMPILED_PATH))
      f.write Marshal.dump(indexes)
      File.delete(COMPILED_PATH) if File.exists?(COMPILED_PATH)
      File.link(f.path, COMPILED_PATH)
    end
  end
  
  def self.compile_to_memory
    properties = PropertyDefinition.all
    records = text_records
    
    @@category_tree = compile_category_tree(properties, records)
    @@image_checksum_index = compile_image_checksum_index
    @@numeric_filtering_index = compile_numeric_filtering_index
    @@product_url_cache = compile_product_url_cache
    @@property_display_cache = compile_property_display_cache(properties)
    @@tag_index = compile_tag_index(properties, records)
    @@text_filtering_index = compile_filtering_index(records.select { |r| r.filterable }, :language_code, :text_value)
    @@text_finding_index = compile_text_finding_index(properties, records)
    @@skip_load = true
  end
  
  def self.ensure_loaded
    return true if @@skip_load
    
    begin
      load
      true
    rescue
      false
    end
  end
  
  def self.excluded_product_ids_for_filters(filters_by_property_id, language_code)
    return [] if filters_by_property_id.empty? or not ensure_loaded
    
    product_ids = []
    text_index = @@text_filtering_index[language_code]
    
    filters_by_property_id.each do |property_id, filter|
      prop_info = @@property_display_cache[property_id]
      next if prop_info.nil?
      
      type = prop_info[:type]
      
      if type == "text"
        inclusions = filter[:data].to_set
        (text_index[property_id] || {}).each do |product_id, values|
          product_ids << product_id if (inclusions & values).empty?
        end
      else
        min, max, unit = filter[:data]
        ((@@numeric_filtering_index[unit] || {})[property_id] || {}).each do |product_id, values|
          product_ids << product_id if min > values.last or max < values.first
        end
      end
    end
    
    product_ids.uniq
  end
  
  def self.filterable_values_for_property_id(property_id, all_prod_ids, relevant_prod_ids, language_code = nil)
    return {} if all_prod_ids.empty? or not ensure_loaded
    
    values_by_root_key = {}
    filtering_indexes(language_code).each do |root_key, products_by_property_id|
      values_by_product_id = products_by_property_id[property_id]
      next if values_by_product_id.nil?      
      
      all_values = values_by_product_id.values_at(*all_prod_ids).flatten.compact.uniq.sort
      relevant_values = 
        if property_id == @@class_property_id then all_values
        else values_by_product_id.values_at(*relevant_prod_ids).flatten.compact.uniq
        end
      values_by_root_key[root_key] = [all_values, relevant_values] unless all_values.empty?
    end
    values_by_root_key
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
    return if source_md5 == @@last_loaded_md5
    
    File.open(COMPILED_PATH) do |f|
      indexes = Marshal.load(f)
      @@category_tree = indexes[:category_tree]
      @@image_checksum_index = indexes[:image_checksums]
      @@numeric_filtering_index = indexes[:numeric_filtering]
      @@product_url_cache = indexes[:product_url_cache]
      @@property_display_cache = indexes[:property_display_cache]
      @@tag_index = indexes[:tag_index]
      @@tag_frequencies = nil
      @@text_filtering_index = indexes[:text_filtering]
      @@text_finding_index = indexes[:text_finding]
    end
    
    @@class_property_id = PropertyDefinition.first(:name => "reference:class").id
    @@sale_price_min_property_id = PropertyDefinition.first(:name => "sale:price_min").id
    
    File.open(SITEMAP_PATH, "w") do |f|
      f.puts '<?xml version="1.0" encoding="UTF-8"?>'
      f.puts '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
      f.puts @@product_url_cache.values.map { |stem| "<url> <loc>http://www.ifloat.biz#{stem}</loc> <changefreq>daily</changefreq> </url>" }
      f.puts '</urlset>'
    end
    
    @@last_loaded_md5 = source_md5
  end
  
  def self.product_ids_for_property_ids(property_ids, language_code)
    return [] if property_ids.empty? or not ensure_loaded
    
    product_id_sets_by_property_id = {}
    filtering_indexes(language_code).each do |root_key, products_by_property_id|
      property_ids.each do |property_id|
        values_by_product_id = products_by_property_id[property_id]
        next if values_by_product_id.nil?
        product_id_set = (product_id_sets_by_property_id[property_id] ||= Set.new)
        product_id_set.merge(values_by_product_id.keys)
      end
    end
    product_id_sets_by_property_id.values.inject { |union, product_ids| union & product_ids }
  end
  
  def self.product_ids_for_phrase(phrase, language_code)
    return [] if phrase.blank? or not ensure_loaded
    
    index = (@@text_finding_index[language_code] || {})
    phrase.downcase.split(/\W+/).map do |word|
       (index[word] || Set.new).to_set
    end.inject { |union, product_ids| union & product_ids }
  end
  
  def self.product_ids_for_tag(phrase, language_code)
    return [] if phrase.blank? or not ensure_loaded
    ((@@tag_index[language_code] || {})[phrase] || []).to_set
  end
  
  def self.product_url(product_id)
    return {} unless ensure_loaded
    @@product_url_cache[product_id]
  end
  
  # TODO: extend to support multiple languages
  def self.property_display_cache
    return {} unless ensure_loaded
    @@property_display_cache
  end
  
  def self.property_ids_for_product_ids(product_ids, language_code)
    return [] if product_ids.empty? or not ensure_loaded
    
    product_ids = product_ids.to_set
    property_ids = Set.new
    
    filtering_indexes(language_code).each do |root_key, products_by_property_id|
      products_by_property_id.each do |property_id, values_by_product_id|
        matching_product_ids = (product_ids & values_by_product_id.keys)
        
        next if matching_product_ids.empty?
        property_ids << property_id and next if matching_product_ids.size < product_ids.size
        next if values_by_product_id.values_at(*product_ids).uniq.size == 1
        property_ids << property_id        
      end
    end
    
    property_ids
  end
  
  def self.sale_price_min_property_id
    @@sale_price_min_property_id if ensure_loaded
  end
  
  def self.tag_frequencies(language_code)
    return {} unless ensure_loaded
    @@tag_frequencies ||= @@tag_index[language_code].inject({}) { |freq, kv| freq.update(kv[0] => kv[1].size) }
  end
  
  
  private
  
  def self.compile_category_tree(properties, records)
    property_names = %w(reference:class_senior reference:class product:type marketing:brand)
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
    brand_pid = properties_by_name["marketing:brand"].id
    values_by_prop_id_by_prod_id.sort_by do |prod_id, values_by_prop_id|
      values_by_prop_id[brand_pid] || ""
    end.each do |prod_id, values_by_prop_id|
      node = tree
      
      property_names[0..-3].each do |prop_name|
        prop_id = properties_by_name[prop_name].id
        prod_value = values_by_prop_id[prop_id]
        node = (node[prod_value] ||= {})
      end
      
      prop_id = properties_by_name[property_names[-2]].id
      prod_value = values_by_prop_id[prop_id]
      (node[prod_value] ||= []) << prod_id
    end
    
    tree
  end
  
  def self.compile_filtering_index(records, root_key, *value_keys)
    index = {}
    records.each do |record|
      root = (index[record[root_key]] ||= {})
      property = (root[record.property_definition_id] ||= {})
      values = (property[record.product_id] ||= [])
      value_keys.each do |key|
        value = record[key]
        values << (value.is_a?(String) ? value : value.to_f)
      end
      values.sort!
    end
    
    index.each do |r, properties|
      properties.each do |property_id, products|
        products.each { |product_id, values| values.uniq! }
      end
    end
    index
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
      SELECT pv.product_id, pv.property_definition_id, pv.unit, pv.min_value, pv.max_value
      FROM property_values pv
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
      WHERE pd.filterable = ?
        AND (pv.min_value IS NOT NULL OR pv.max_value IS NOT NULL)
    SQL
    
    records = repository.adapter.select(query, true)
    compile_filtering_index(records, :unit, :min_value, :max_value)
  end
  
  def self.compile_product_url_cache
    query =<<-SQL
      SELECT product_id, text_value
      FROM property_values
      WHERE property_definition_id = ?
        AND language_code = 'ENG'
        AND text_value IS NOT NULL
        AND sequence_number = 1
    SQL
    
    title_property = PropertyDefinition.first(:name => "auto:title")
    return {} if title_property.nil?
    
    urls_by_product_id = {}
    repository.adapter.select(query, title_property.id).each do |record|
      title = record.text_value.desuperscript.downcase.delete("'").gsub(/[^a-z0-9]+/, "-")[0, 256]
      urls_by_product_id[record.product_id] = "/products/#{title}-#{record.product_id}"
    end
    urls_by_product_id
  end
  
  # TODO: extend to support other languages
  def self.compile_property_display_cache(properties)
    friendly_names = PropertyDefinition.friendly_name_sections(properties, "ENG")
    icon_urls = PropertyDefinition.icon_urls_by_property_id(properties)
    
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
  
  def self.compile_tag_index(properties, records)
    property_names = %w(reference:class_senior reference:tag).to_set
    pd_ids = properties.select { |pd| property_names.include?(pd.name) }.map { |pd| pd.id }.to_set
    
    index = {}
    records.each do |record|
      next unless pd_ids.include?(record.property_definition_id)
      language = (index[record.language_code] ||= {})
      (language[record.text_value] ||= []) << record.product_id
    end
    
    index.each do |language, phrases|
      phrases.each { |phrases, product_ids| product_ids.uniq! }
    end
    index
  end
  
  def self.compile_text_finding_index(properties, records)
    index = {}
    prod_ids_by_values_by_prop_ids = {}
    
    records.each do |record|
      prod_ids_by_values = (prod_ids_by_values_by_prop_ids[record.property_definition_id] ||= {})
      (prod_ids_by_values[record.text_value] ||= []) << record.product_id
            
      next unless record.findable
      
      record.text_value.downcase.split(/[^a-z0-9']+/).uniq.each do |word|
        language = (index[record.language_code] ||= {})
        (language[word] ||= []) << record.product_id        
      end
    end
    
    # TODO: contemplate how to make associated words multilingual
    eng_index = (index["ENG"] ||= {})
    properties_by_name = properties.hash_by(:name)
    AssociatedWord.all.each do |aword|
      eng_index[aword.word] = (eng_index[aword.word] || []) + aword.rules.map do |property_name, value|
        prop_id = properties_by_name[property_name].id
        (prod_ids_by_values_by_prop_ids[prop_id] || {})[value] || []
      end.inject { |union, product_ids| union & product_ids }
    end
    
    index.each do |language, words|
      words.each { |word, product_ids| product_ids.uniq! }
    end
    index
  end
  
  def self.filtering_indexes(language_code)
    indexes = @@numeric_filtering_index.to_a
    text_index = @@text_filtering_index[language_code]
    indexes << [language_code, text_index] unless text_index.nil?
    indexes
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