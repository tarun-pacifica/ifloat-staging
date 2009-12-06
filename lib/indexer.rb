module Indexer
  COMPILED_PATH = "caches/indexer.marshal"
  
  @@class_property_id = nil
  @@image_checksum_index = {}
  @@last_loaded_md5 = nil
  @@numeric_filtering_index = {}
  @@text_filtering_index = {}
  @@text_finding_index = {}
  
  def self.class_property_id
    @@class_property_id
  end
  
  def self.compile
    Tempfile.open(File.basename(COMPILED_PATH)) do |f|
      records = text_records
      indexes = {
        :image_checksums => compile_image_checksum_index,
        :numeric_filtering => compile_numeric_filtering_index,
        :text_filtering => compile_text_filtering_index(records),
        :text_finding => compile_text_finding_index(records)
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
    
  def self.excluded_product_ids_for_numeric_filters(filters)
    return [] if filters.empty? or not ensure_loaded
    
    filters_by_pid = {}
    filters.each { |filter| filters_by_pid[filter[:prop_id]] = filter }
    
    product_ids = []
    @@numeric_filtering_index.each do |property_id, units_by_product_id|
      filter = filters_by_pid[property_id]
      next if filter.nil?
      
      min, max, unit, limits = filter[:data]
      units_by_product_id.each do |product_id, min_max_by_unit|
        min_max = min_max_by_unit[unit]
        next if min_max.nil?
        product_ids << product_id if min > min_max.last or max < min_max.first
      end
    end
    product_ids.uniq
  end
  
  def self.excluded_product_ids_for_text_filters(filters, language_code)
    return [] if filters.empty? or not ensure_loaded
    
    filters_by_pid = {}
    filters.each { |filter| filters_by_pid[filter[:prop_id]] = filter }
    
    product_ids = []
    (@@text_filtering_index[language_code] || {}).each do |property_id, products|
      filter = filters_by_pid[property_id]
      next if filter.nil?
      
      exclusions = filter[:data]
      products.each { |product_id, values| product_ids << product_id if (values - exclusions).empty? }
    end
    product_ids.uniq
  end
  
  def self.filterable_text_property_ids_for_product_ids(product_ids, language_code)
    return [] if product_ids.empty? or not ensure_loaded
    
    (@@text_filtering_index[language_code] || {}).map do |property_id, products|
      (products.keys & product_ids).empty? ? nil : property_id
    end.compact
  end
  
  def self.filterable_text_values_for_product_ids(all_product_ids, relevant_product_ids, language_code, single_property_id = nil)
    return {} if all_product_ids.empty? or not ensure_loaded
    
    values_by_property_id = {}
    (@@text_filtering_index[language_code] || {}).each do |property_id, products|
      next unless single_property_id.nil? or single_property_id == property_id
      all_values = products.values_at(*all_product_ids).flatten.compact.uniq.sort
      relevant_values = products.values_at(*relevant_product_ids).flatten.uniq.compact
      values_by_property_id[property_id] = [all_values, relevant_values] unless all_values.empty?
    end
    values_by_property_id
  end
  
  def self.image_checksums_for_product_ids(product_ids)
    product_ids.group_by { |id| @image_checksums_for_product_ids[id] }
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
      @@text_filtering_index = indexes[:text_filtering]
      @@text_finding_index = indexes[:text_finding]
    end
    
    @@class_property_id = PropertyDefinition.first(:name => "reference:class").id
    
    @@last_loaded_md5 = source_md5
  end
  
  def self.numeric_limits_for_product_ids(product_ids)
    return {} if product_ids.empty? or not ensure_loaded
    
    limits_by_unit_by_property_id = {}
    
    @@numeric_filtering_index.each do |property_id, units_by_product_id|
      relevant_product_ids = (product_ids & units_by_product_id.keys)
      next if relevant_product_ids.empty?
      
      limits_by_unit = limits_by_unit_by_property_id[property_id] = {}
      units_by_product_id.values_at(*relevant_product_ids).each do |min_max_by_unit|
        limits_by_unit.update(min_max_by_unit) do |unit, old_min_max, new_min_max|
          (old_min_max + new_min_max).minmax
        end
      end
    end
    
    limits_by_unit_by_property_id
  end
  
  def self.product_ids_for_filterable_property_ids(property_ids, language_code)
    return [] if property_ids.empty? or not ensure_loaded
    
    values_by_product_ids = (@@text_filtering_index[language_code] || {}).values_at(*property_ids)
    values_by_product_ids += @@numeric_filtering_index.values_at(*property_ids)
    product_id_sets = values_by_product_ids.compact.map { |values_by_product_id| values_by_product_id.keys }
    product_id_sets.inject { |union, product_ids| product_ids.empty? ? union : (union & product_ids) }
  end
  
  def self.product_ids_for_phrase(phrase, language_code)
    return [] if phrase.blank? or not ensure_loaded

    phrase.downcase.split(/\W+/).map do |word|
      (@@text_finding_index[language_code] || {})[word] || []
    end.inject { |union, product_ids| union & product_ids }
  end
  
  
  private
  
  def self.compile_image_checksum_index
    # TODO: remove MS hack once we are vending all products rather than just MarineStore's
    #       first two INNER JOINS and second WHERE condition
    query =<<-SQL
      SELECT p.id, a.checksum
      FROM products p
        INNER JOIN product_mappings pm ON p.id = pm.definitive_product_id
        INNER JOIN companies c ON pm.company_id = c.id
        INNER JOIN attachments at ON p.id = at.product_id
        INNER JOIN assets a ON at.asset_id = a.id
      WHERE p.type = 'DefinitiveProduct'
        AND c.reference = ?
        AND at.role = 'image'
      ORDER BY at.sequence_number
    SQL
    
    ici = {}
    repository.adapter.query(query, "GBR-02934378").each do |record|
      ici[record.id] ||= record.checksum
    end
    ici
  end
  
  def self.compile_numeric_filtering_index
    # TODO: remove MS hack once we are vending all products rather than just MarineStore's
    #       two final INNER JOINS and final WHERE
    query =<<-SQL
      SELECT pv.product_id, pv.property_definition_id, pv.unit, pv.min_value, pv.max_value
      FROM property_values pv
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
        INNER JOIN product_mappings pm ON pv.product_id = pm.definitive_product_id
        INNER JOIN companies c ON pm.company_id = c.id
      WHERE pd.filterable = ?
        AND (pv.min_value IS NOT NULL OR pv.max_value IS NOT NULL)
        AND c.reference = ?
    SQL
    
    nfi = {}
    repository.adapter.query(query, true, "GBR-02934378").each do |record|
      products = (nfi[record.property_definition_id] ||= {})
      units = (products[record.product_id] ||= {})
      min_max = (units[record.unit] || [])
      units[record.unit] = ([record.min_value.to_f, record.max_value.to_f] + min_max).minmax
    end
    nfi
  end
  
  def self.compile_text_filtering_index(records)
    tfi = {}
    records.each do |record|
      next unless record.filterable
      
      language = (tfi[record.language_code] ||= {})
      property = (language[record.property_definition_id] ||= {})
      (property[record.product_id] ||= []) << record.text_value
    end
    
    tfi.each do |language, properties|
      properties.each do |property_id, products|
        products.each { |product_id, values| values.uniq! }
      end
    end
    tfi
  end
  
  def self.compile_text_finding_index(records)
    tfi = {}
    records.each do |record|
      next unless record.findable
      
      record.text_value.downcase.split(/\W+/).select { |word| word.size > 2 }.uniq.each do |word|
        language = (tfi[record.language_code] ||= {})
        (language[word] ||= []) << record.product_id        
      end
    end
    
    tfi.each do |language, words|
      words.each { |word, product_ids| product_ids.uniq! }
    end
    tfi
  end
  
  def self.text_records
    # TODO: remove MS hack once we are vending all products rather than just MarineStore's
    #       two final INNER JOINS and final WHERE
    query =<<-SQL
      SELECT pd.findable, pd.filterable, pv.product_id, pv.property_definition_id, pv.language_code, pv.text_value
      FROM property_values pv
        INNER JOIN products p ON pv.product_id = p.id
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
        INNER JOIN product_mappings pm ON pv.product_id = pm.definitive_product_id
        INNER JOIN companies c ON pm.company_id = c.id
      WHERE p.type = 'DefinitiveProduct'
        AND pv.text_value IS NOT NULL
        AND c.reference = ?
    SQL
    
    repository.adapter.query(query, "GBR-02934378")
  end
end