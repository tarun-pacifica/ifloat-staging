class Indexer
  @@numeric_filtering_index = {}
  @@text_finding_index = {}
  @@text_filtering_index = {}
  @@last_compile = nil
  
  def self.compile
    numeric_filtering_index = compile_numeric_filtering_index
    
    records = text_records
    text_finding_index = compile_text_finding_index(records)
    text_filtering_index = compile_text_filtering_index(records)
    
    @@numeric_filtering_index = numeric_filtering_index
    @@text_finding_index = text_finding_index
    @@text_filtering_index = text_filtering_index
    
    @@last_compile = DateTime.now
  end
  
  def self.compile_needed?
    return true if @@last_compile.nil?
    last_import_run = ImportEvent.first(:succeeded => true, :order => [:completed_at.desc])
    return false if last_import_run.nil?
    return last_import_run.completed_at >= @@last_compile
  end
  
  def self.filterable_numeric_excluded_product_ids(filters, auto_compile = true)
    return [] if filters.empty?
    
    compile if auto_compile and compile_needed?
    
    filters_by_pid = filters.hash_by(:property_definition_id)
    
    product_ids = []
    @@numeric_filtering_index.each do |property_id, products_by_unit|
      filter = filters_by_pid[property_id]
      next if filter.nil?
      
      min, max, unit = filter.chosen
      (products_by_unit[unit] || {}).each do |product_id, min_max|
        product_ids << product_id if min > min_max.last or max < min_max.first
      end
    end
    product_ids.uniq
  end
  
  def self.filterable_product_ids_for_property_ids(property_ids, language_code, auto_compile = true)
    compile if auto_compile and compile_needed?
    
    property_ids = (@@text_filtering_index[language_code] || {}).values_at(*property_ids).map do |values_by_product_id|
      (values_by_product_id || {}).keys
    end.compact
    
    property_ids += @@numeric_filtering_index.values_at(*property_ids).map do |products_by_unit|
      (products_by_unit || {}).values.map do |minmax_by_product_id|
        minmax_by_product_id.keys
      end
    end
    
    property_ids.flatten.uniq
  end
  
  def self.filterable_text_excluded_product_ids(filters, language_code, auto_compile = true)
    return [] if filters.empty?
    
    compile if auto_compile and compile_needed?
    
    filter_ids = filters.map { |filter| filter.id }
    exclusions_by_fid = TextFilterExclusion.all(:text_filter_id => filter_ids).group_by { |tfe| tfe.text_filter_id }
    filters_by_pid = filters.hash_by(:property_definition_id)
    
    product_ids = []
    (@@text_filtering_index[language_code] || {}).each do |property_id, products|
      filter = filters_by_pid[property_id]
      next if filter.nil?
      
      exclusions = exclusions_by_fid[filter.id].map { |tfe| tfe.value }
      products.each { |product_id, values| product_ids << product_id unless (values & exclusions).empty? }
    end
    product_ids.uniq
  end
  
  def self.filterable_text_property_ids_for_product_ids(product_ids, language_code, auto_compile = true)
    return [] if product_ids.empty?
    
    compile if auto_compile and compile_needed?

    (@@text_filtering_index[language_code] || {}).map do |property_id, products|
      (products.keys & product_ids).empty? ? nil : property_id
    end.compact
  end
  
  def self.filterable_text_values_for_product_ids(all_product_ids, relevant_product_ids, language_code, auto_compile = true)
    return {} if all_product_ids.empty?
    
    compile if auto_compile and compile_needed?
    
    values_by_property_id = {}
    (@@text_filtering_index[language_code] || {}).each do |property_id, products|
      all_values = products.values_at(*all_product_ids).flatten.compact.uniq.sort
      relevant_values = products.values_at(*relevant_product_ids).flatten.uniq.compact
      values_by_property_id[property_id] = [all_values, relevant_values] unless all_values.empty?
    end
    values_by_property_id
  end
  
  def self.last_compile
    @@last_compile
  end
  
  def self.numeric_limits_for_product_ids(product_ids, auto_compile = true)
    return {} if product_ids.empty?
    
    compile if auto_compile and compile_needed?
    limits_by_unit_by_property_id = {}
    
    @@numeric_filtering_index.each do |property_id, products_by_unit|
      products_by_unit.each do |unit, min_max_by_product_id|
        relevant_product_ids = (product_ids & min_max_by_product_id.keys)
        next if relevant_product_ids.empty?
        
        minima, maxima = min_max_by_product_id.values_at(*relevant_product_ids).transpose
        limits_by_unit = (limits_by_unit_by_property_id[property_id] ||= {})
        limits_by_unit[unit] = [minima.min, maxima.max]
      end
    end
    
    limits_by_unit_by_property_id
  end
  
  def self.product_ids_for_phrase(phrase, language_code, auto_compile = true)
    compile if auto_compile and compile_needed?
    phrase.downcase.split(/\W+/).map do |word|
      (@@text_finding_index[language_code] || {})[word] || []
    end.inject { |union, product_ids| union & product_ids }
  end
  
  
  private
  
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
      units = (nfi[record.property_definition_id] ||= {})
      products = (units[record.unit] ||= {})
      min_max = (products[record.product_id] || [])
      products[record.product_id] = ([record.min_value, record.max_value] + min_max).minmax
    end
    nfi
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