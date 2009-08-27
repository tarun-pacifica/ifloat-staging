# = Summary
#
# PropertyValueDefinition is a simple class that allows string values to be associated with definitions in an arbitrary number of languages. The namespace for each defintion is local to a given PropertyType. Definitions are limited to 255 characters to keep them short and efficient. Ideally they should be no more than three sentences (for which reason they also have no paragraph support).
#
# === Sample Data
#
# language_code:: 'ENG'
# value:: 'RAM'
# defintion:: 'Random Access Memory'
#
class PropertyValueDefinition
  include DataMapper::Resource
  
  property :id, Serial
  property :language_code, String, :nullable => false, :format => /^[A-Z]{3}$/
  property :value, String, :nullable => false
  property :definition, String, :nullable => false, :size => 255
  
  belongs_to :property_type
  
  validates_present :property_type_id
  validates_is_unique :value, :scope => [:property_type_id, :language_code]
  
  def self.definitions_by_property_id(property_ids, language_code)
    return {} if property_ids.empty?
    
    query =<<-EOS
      SELECT pd.id, pvd.value, pvd.definition
      FROM property_value_definitions pvd
        INNER JOIN property_types pt ON pvd.property_type_id = pt.id
        INNER JOIN property_definitions pd ON pt.id = pd.property_type_id
      WHERE pvd.language_code = ?
        AND pd.id IN ?
    EOS
    
    dbpi = {}
    repository.adapter.query(query, language_code, property_ids).each do |record|
      (dbpi[record.id] ||= {})[record.value] = record.definition
    end
    dbpi
  end
end
