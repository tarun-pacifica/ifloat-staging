module Indexer
  COMPILED_PATH = "caches/indexer.marshal"
  
  @@class_property_id = nil
  @@image_checksum_index = {}
  @@last_loaded_md5 = nil
  @@numeric_filtering_index = {}
  @@property_display_cache = {}
  @@text_filtering_index = {}
  @@text_finding_index = {}
  
  def self.class_property_id
    @@class_property_id
  end
  
  def self.compile
    Tempfile.open(File.basename(COMPILED_PATH)) do |f|
      records = text_records
      indexes = {
        :image_checksums         => compile_image_checksum_index,
        :numeric_filtering       => compile_numeric_filtering_index,
        :property_display_cache  => compile_property_display_cache,
        :text_filtering          => compile_filtering_index(records.select { |r| r.filterable }, :language_code, :text_value),
        :text_finding            => compile_text_finding_index(records)
      }
      
      FileUtils.mkpath(File.dirname(COMPILED_PATH))
      f.write Marshal.dump(indexes)
      File.delete(COMPILED_PATH) if File.exists?(COMPILED_PATH)
      File.link(f.path, COMPILED_PATH)
    end
  end
  
  def self.ensure_loaded
    begin
      load
      true
    rescue
      false
    end
  end
  
  # TODO: reimplement
  def self.excluded_product_ids_for_numeric_filters(filters_by_property_id)
    raise "reimplement"
    return [] if filters_by_property_id.empty? or not ensure_loaded
    
    product_ids = []
    @@numeric_filtering_index.each do |property_id, units_by_product_id|
      min, max, unit = filters_by_property_id[property_id]
      next if min.nil?
      
      units_by_product_id.each do |product_id, min_max_by_unit|
        min_max = min_max_by_unit[unit]
        next if min_max.nil?
        product_ids << product_id if min > min_max.last or max < min_max.first
      end
    end
    product_ids.uniq
  end
  
  def self.excluded_product_ids_for_text_filters(filters_by_property_id, language_code)
    return [] if filters_by_property_id.empty? or not ensure_loaded
    
    product_ids = []
    (@@text_filtering_index[language_code] || {}).each do |property_id, products|
      inclusions = filters_by_property_id[property_id]
      next if inclusions.nil?
      
      products.each { |product_id, values| product_ids << product_id if (values & inclusions).empty? }
    end
    product_ids.uniq
  end
  
  # TODO: get rid of extended logic here and revert to simple group_by once all ingested products are guaranteed to have a primary image - also should be able to get rid of 'no image' image in this case
  def self.image_checksums_for_product_ids(product_ids)
    return {} if product_ids.empty? or not ensure_loaded
    
    prod_ids_by_checksum = product_ids.group_by { |id| @@image_checksum_index[id] }
    prod_ids_by_checksum.delete(nil)
    prod_ids_by_checksum
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
      @@image_checksum_index = indexes[:image_checksums]
      @@numeric_filtering_index = indexes[:numeric_filtering]
      @@property_display_cache = indexes[:property_display_cache]
      @@text_filtering_index = indexes[:text_filtering]
      @@text_finding_index = indexes[:text_finding]
    end
    
    @@class_property_id = PropertyDefinition.first(:name => "reference:class").id
    
    @@last_loaded_md5 = source_md5
  end
  
  def self.product_ids_for_property_ids(property_ids, language_code)
    return [] if property_ids.empty? or not ensure_loaded
    
    filtering_indexes(language_code).map do |root_key, products_by_property_id|
      values_by_products = products_by_property_id.values_at(*property_ids).compact
      values_by_products.map { |values_by_product| values_by_product.keys }
    end.flatten.uniq
  end
  
  def self.product_ids_for_phrase(phrase, language_code)
    return [] if phrase.blank? or not ensure_loaded

    phrase.downcase.split(/\W+/).map do |word|
       (@@text_finding_index[language_code] || {})[word] || []
    end.inject { |union, product_ids| union & product_ids }
  end
  
  # TODO: extend to support multiple languages
  def self.property_display_cache
    return {} unless ensure_loaded
    @@property_display_cache
  end
  
  def self.property_ids_for_product_ids(product_ids, language_code)
    return [] if product_ids.empty? or not ensure_loaded
    
    filtering_indexes(language_code).map do |root_key, products_by_property_id|
      products_by_property_id.map do |property_id, values_by_product_id|
        (values_by_product_id.keys & product_ids).empty? ? nil : property_id
      end.compact
    end.flatten.uniq
  end
  
  def self.filterable_values_for_property_id(property_id, all_prod_ids, relevant_prod_ids, language_code = nil)
    return {} if all_prod_ids.empty? or not ensure_loaded
    
    values_by_root_key = {}
    filtering_indexes(language_code).each do |root_key, products_by_property_id|
      values_by_product_id = products_by_property_id[property_id]
      next if values_by_product_id.nil?      
      
      all_values = values_by_product_id.values_at(*all_prod_ids).flatten.compact.uniq.sort
      relevant_values = values_by_product_id.values_at(*relevant_prod_ids).flatten.compact.uniq
      values_by_root_key[root_key] = [all_values, relevant_values] unless all_values.empty?
    end
    values_by_root_key
  end
  
  private
  
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
    end
    
    index.each do |r, properties|
      properties.each do |property_id, products|
        products.each { |product_id, values| values.uniq! }
      end
    end
    index
  end
  
  def self.compile_image_checksum_index
    # TODO: remove MS hack once we are vending all products rather than just MarineStore's
    #       first two INNER JOINS and second WHERE condition
    query =<<-SQL
      SELECT p.id, a.checksum
      FROM products p
        INNER JOIN product_mappings pm ON p.id = pm.product_id
        INNER JOIN companies c ON pm.company_id = c.id
        INNER JOIN attachments at ON p.id = at.product_id
        INNER JOIN assets a ON at.asset_id = a.id
      WHERE c.reference = ?
        AND at.role = 'image'
      ORDER BY at.sequence_number
    SQL
    
    index = {}
    repository.adapter.select(query, "GBR-02934378").each do |record|
      index[record.id] ||= record.checksum
    end
    index
  end
  
  def self.compile_numeric_filtering_index
    # TODO: remove MS hack once we are vending all products rather than just MarineStore's
    #       two final INNER JOINS and final WHERE
    query =<<-SQL
      SELECT pv.product_id, pv.property_definition_id, pv.unit, pv.min_value, pv.max_value
      FROM property_values pv
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
        INNER JOIN product_mappings pm ON pv.product_id = pm.product_id
        INNER JOIN companies c ON pm.company_id = c.id
      WHERE pd.filterable = ?
        AND (pv.min_value IS NOT NULL OR pv.max_value IS NOT NULL)
        AND c.reference = ?
    SQL
    
    records = repository.adapter.select(query, true, "GBR-02934378")
    compile_filtering_index(records, :unit, :min_value, :max_value)
  end
  
  # TODO: extend to support other languages
  def self.compile_property_display_cache
    properties = PropertyDefinition.all
    friendly_names = PropertyDefinition.friendly_name_sections(properties, "ENG")
    icon_urls = PropertyDefinition.icon_urls_by_property_id(properties)
    
    cache = {}
    properties.each do |property|
      section, name = friendly_names[property.id]
      cache[property.id] = {
        :id       => property.id,
        :seq_num  => property.sequence_number,
        :section  => section,
        :name     => name,
        :icon_url => icon_urls[property.id],
        :type     => property.property_type.core_type,
      }
    end
    cache
  end
  
  def self.compile_text_finding_index(records)
    index = {}
    records.each do |record|
      next unless record.findable
      
      record.text_value.downcase.split(/\W+/).select { |word| word.size > 2 }.uniq.each do |word|
        language = (index[record.language_code] ||= {})
        (language[word.gsub(/[^a-zA-Z0-9]+/, "")] ||= []) << record.product_id        
      end
    end
    
    index.each do |language, words|
      words.each { |word, product_ids| product_ids.uniq! }
    end
    index
  end
  
  def self.filtering_indexes(language_code)
    text_index = @@text_filtering_index[language_code]
    @@numeric_filtering_index.to_a << (text_index.nil? ? [] : [language_code, text_index])
  end
  
  def self.text_records
    # TODO: remove MS hack once we are vending all products rather than just MarineStore's
    #       two final INNER JOINS and final WHERE
    query =<<-SQL
      SELECT pd.findable, pd.filterable, pv.product_id, pv.property_definition_id, pv.language_code, pv.text_value
      FROM property_values pv
        INNER JOIN products p ON pv.product_id = p.id
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
        INNER JOIN product_mappings pm ON pv.product_id = pm.product_id
        INNER JOIN companies c ON pm.company_id = c.id
      WHERE pv.text_value IS NOT NULL
        AND c.reference = ?
    SQL
    
    repository.adapter.select(query, "GBR-02934378")
  end
end