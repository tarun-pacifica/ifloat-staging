class Indexer
  @@numeric_filtering_index = {}
  @@phrase_index = {}
  @@text_filtering_index = {}
  @@last_compile = nil
  
  def self.compile
    nfi = compile_numeric_filtering_index
    pi = compile_phrase_index
    tfi = compile_text_filtering_index
    
    @@numeric_filtering_index = nfi
    @@phrase_index = pi
    @@text_filtering_index = tfi
    
    @@last_compile = DateTime.now
  end
  
  def self.compile_needed?
    return true if @@last_compile.nil?
    last_import_run = ImportEvent.first(:succeeded => true, :order => [:completed_at.desc])
    return false if last_import_run.nil?
    return last_import_run.completed_at >= @@last_compile
  end
  
  def self.filterable_text_property_ids_for_product_ids(product_ids, auto_compile = true)
    compile if auto_compile and compile_needed?
    @@text_filtering_index.values_at(*product_ids).flatten.uniq
  end
  
  def self.last_compile
    @@last_compile
  end
  
  def self.numeric_limits_for_product_ids(product_ids, auto_compile = true)
    return {} if product_ids.empty?
    
    compile if auto_compile and compile_needed?
    limits_by_unit_by_property_id = {}
    
    @@numeric_filtering_index.each do |property_id, units|
      units.each do |unit, extrema|
        relevant_product_ids = (product_ids & extrema.keys)
        next if relevant_product_ids.empty?
        
        minima, maxima = extrema.values_at(*relevant_product_ids).transpose
        min = (minima.any? { |v| v.nil? } ? nil : minima.min)
        max = (maxima.any? { |v| v.nil? } ? nil : maxima.max)
        limits_by_unit = (limits_by_unit_by_property_id[property_id] ||= {})
        limits_by_unit[unit] = [min, max]
      end
    end
    
    limits_by_unit_by_property_id
  end
  
  def self.product_ids_for_phrase(phrase, language_code, auto_compile = true)
    compile if auto_compile and compile_needed?
    phrase.downcase.split(/\W+/).map do |word|
      (@@phrase_index[language_code] || {})[word] || []
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
      (units[record.unit] ||= {})[record.product_id] = [record.min_value, record.max_value]
    end
    nfi
  end
  
  def self.compile_phrase_index
    # TODO: remove MS hack once we are vending all products rather than just MarineStore's
    #       two final INNER JOINS and final WHERE
    query =<<-SQL
      SELECT pv.product_id, pv.language_code, pv.text_value
      FROM property_values pv
        INNER JOIN products p ON pv.product_id = p.id
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
        INNER JOIN product_mappings pm ON pv.product_id = pm.definitive_product_id
        INNER JOIN companies c ON pm.company_id = c.id
      WHERE p.type = 'DefinitiveProduct'
        AND pd.findable = ?
        AND pv.text_value IS NOT NULL
        AND c.reference = ?
    SQL
    
    pi = {}
    repository.adapter.query(query, true, "GBR-02934378").each do |record|
      record.text_value.downcase.split(/\W+/).select { |word| word.size > 2 }.uniq.each do |word|
        language = (pi[record.language_code] ||= {})
        (language[word] ||= []) << record.product_id        
      end
    end
    
    pi.each do |language, words|
      words.each { |word, product_ids| product_ids.uniq! }
    end
    pi
  end
  
  def self.compile_text_filtering_index
    # TODO: remove MS hack once we are vending all products rather than just MarineStore's
    #       two final INNER JOINS and final WHERE
    query =<<-SQL
      SELECT DISTINCT pv.product_id, pv.property_definition_id
      FROM property_values pv
        INNER JOIN products p ON pv.product_id = p.id
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
        INNER JOIN product_mappings pm ON pv.product_id = pm.definitive_product_id
        INNER JOIN companies c ON pm.company_id = c.id
      WHERE p.type = 'DefinitiveProduct'
        AND pd.filterable = ?
        AND pv.text_value IS NOT NULL
        AND c.reference = ?
    SQL
    
    tfi = {}
    repository.adapter.query(query, true, "GBR-02934378").each do |record|
      (tfi[record.product_id] ||= []) << record.property_definition_id
    end
    tfi
  end
end