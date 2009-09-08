class Indexer
  @@index = {}
  @@last_compile = nil
  
  def self.compile
    index = {}
    
    query =<<-SQL
      SELECT pv.product_id, pv.language_code, pv.text_value
      FROM property_values pv
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
      WHERE pd.filterable = ?
        AND text_value IS NOT NULL
    SQL
    
    repository.adapter.query(query, true).each do |record|
      record.text_value.downcase.split(/\W+/).select { |word| word.size > 2 }.uniq.each do |word|
        language = (index[record.language_code] ||= {})
        (language[word] ||= []) << record.product_id
      end
    end
    
    index.each do |language, words|
      words.each { |word, product_ids| product_ids.uniq! }
    end
    
    @@index = index
    @@last_compile = DateTime.now
  end
  
  def self.compile_needed?
    return true if @@last_compile.nil?
    last_import_run = ImportEvent.first(:succeeded => true, :order => [:completed_at.desc])
    return false if last_import_run.nil?
    return last_import_run.completed_at >= @@last_compile
  end
  
  def self.lookup(language_code, word)
    compile if compile_needed?
    (@@index[language_code] || {})[word.downcase] || []
  end
end