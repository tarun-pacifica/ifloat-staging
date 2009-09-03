# = Summary
#
# See the PropertyValue superclass.
#
class TextPropertyValue < PropertyValue
  property :language_code, String, :format => /^[A-Z]{3}$/
  property :text_value, Text
  
  validates_present :language_code, :text_value
  
  # TODO: document and test
  def self.filter_preferred_languages(property_ids_by_language, product_ids)
    return {} if property_ids_by_language.empty? or product_ids.empty?
    
    query = "SELECT DISTINCT property_definition_id FROM property_values WHERE product_id IN ? AND "
    bind_values = [product_ids]
    
    query_chunks = property_ids_by_language.map do |language, property_ids|
      bind_values << language << property_ids
      "(language_code = ? AND property_definition_id IN ?)"
    end
    query += query_chunks.join(" OR ")
    
    filtered_property_ids = repository.adapter.query(query, *bind_values)
    
    property_ids_by_language.keys.each do |language|
      property_ids_by_language[language] &= filtered_property_ids
    end
    property_ids_by_language
  end
  
  # TODO: document and test
  def self.preferred_languages(property_ids, languages_in_preference_order)
    return {} if (not property_ids.nil? and property_ids.empty?) or languages_in_preference_order.empty?
    
    language_indices = {}
    languages_in_preference_order.each_with_index do |language, i|
      language_indices[language] = i
    end
    
    query =<<-EOS
      SELECT DISTINCT property_definition_id, language_code
      FROM property_values
      WHERE text_value IS NOT NULL
        AND language_code IN ?
    EOS
    
    bind_values = [languages_in_preference_order]
    unless property_ids.nil?
      query += " AND property_definition_id IN ?"
      bind_values << property_ids
    end
    
    languages_by_property_id = {}
    
    repository.adapter.query(query, *bind_values).map do |record|
      [record.language_code, record.property_definition_id]
    end.sort_by { |language, property_id| language_indices[language] }.reverse_each do |language, property_id|
      languages_by_property_id[property_id] = language
    end
    
    languages_by_property_id.keys.group_by { |property_id| languages_by_property_id[property_id] }
  end
  
  def self.product_ids_matching_spec(spec, language_codes)
    matching_product_ids = spec.split.map do |word|
      product_ids_matching_word(word, language_codes)
    end
    
    matching_product_ids.inject { |union, product_ids| union & product_ids }
  end
  
  # TODO: spec
  def self.parse_or_error(value)
    raise "invalid characters in #{value.inspect}" unless value =~ /\A[\n\w\.\/\- !@%()'";:,?®™]+\z/
    {:text_value => value}
  end
  
  # TODO: document and test
  def self.translated_values(product_ids, languages_in_preference_order)
    return {} if product_ids.empty?
    
    properties_by_id = {}
    PropertyDefinition.all("values.product_id" => product_ids).each do |property|
      properties_by_id[property.id] = property
    end
    property_ids_by_language = preferred_languages(properties_by_id.keys, languages_in_preference_order)
    
    query = "SELECT product_id, property_definition_id, text_value FROM property_values WHERE product_id IN ? AND "
    bind_values = [product_ids]
    
    query_chunks = property_ids_by_language.map do |language, property_ids|
      bind_values << language << property_ids
      "(language_code = ? AND property_definition_id IN ?)"
    end
    query += query_chunks.join(" OR ")
    
    values_by_property_by_product_id = {}
    product_ids.each do |product_id|
      values_by_property_by_product_id[product_id] = {}
    end
    
    repository.adapter.query(query, *bind_values).each do |record|
      values_by_property = values_by_property_by_product_id[record.product_id]
      property = properties_by_id[record.property_definition_id]
      values = (values_by_property[property] ||= [])
      values << record.text_value
    end
    
    values_by_property_by_product_id
  end
  
  def self.text? # TODO: spec (in this class and parent only)
    true
  end
  
  def to_s # TODO: spec
    text_value
  end
  
  def value
    text_value
  end
  
  
  private
  
  def self.product_ids_matching_word(word, language_codes)
    # TODO: remove MS hack once we are vending all products rather than just MarineStore's
    #       two final INNER JOINS and final WHERE
    
    query =<<-EOS
      SELECT DISTINCT p.id
      FROM products p
        INNER JOIN property_values pv ON p.id = pv.product_id
        INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
        INNER JOIN product_mappings pm ON p.id = pm.definitive_product_id
        INNER JOIN companies c ON pm.company_id = c.id
      WHERE p.type = 'DefinitiveProduct'
        AND pd.findable = ?
        AND pv.language_code IN ?
        AND pv.text_value LIKE ?
        AND c.reference = ?
    EOS
    
    repository(:default).adapter.query(query, true, language_codes, "%#{word}%", "GBR-02934378")
  end
end
