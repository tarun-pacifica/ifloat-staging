class Indexer
  @@phrase_index = {}
  @@property_index = {}
  @@last_compile = nil
  
  def self.compile
    phrase_index = {}
    property_index = {}
    
    # TODO: remove MS hack once we are vending all products rather than just MarineStore's
    #       two final INNER JOINS and final WHERE
    query =<<-SQL
      SELECT pv.product_id, pv.property_definition_id, pv.language_code, pv.text_value
      FROM property_values pv
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
        INNER JOIN product_mappings pm ON pv.product_id = pm.definitive_product_id
        INNER JOIN companies c ON pm.company_id = c.id
      WHERE pd.filterable = ?
        AND pv.text_value IS NOT NULL
        AND c.reference = ?
    SQL
    
    repository.adapter.query(query, true, "GBR-02934378").each do |record|
      record.text_value.downcase.split(/\W+/).select { |word| word.size > 2 }.uniq.each do |word|
        language = (phrase_index[record.language_code] ||= {})
        (language[word] ||= []) << record.product_id        
        (property_index[record.product_id] ||= []) << record.property_definition_id
      end
    end
    
    phrase_index.each do |language, words|
      words.each { |word, product_ids| product_ids.uniq! }
    end
    
    property_index.each { |product_id, property_ids| property_ids.uniq! }
    
    @@phrase_index = phrase_index
    @@property_index = property_index
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
    @@property_index.values_at(*product_ids).flatten.uniq
  end
  
  def self.last_compile
    @@last_compile
  end
  
  def self.product_ids_for_phrase(phrase, language_code, auto_compile = true)
    compile if auto_compile and compile_needed?
    phrase.downcase.split(/\W+/).map do |word|
      (@@phrase_index[language_code] || {})[word] || []
    end.inject { |union, product_ids| union & product_ids }
  end
end