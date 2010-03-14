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
  property :language_code, String, :required => true, :format => /^[A-Z]{3}$/, :unique_index => :val_per_lang_per_prop_type
  property :value, String, :required => true, :unique_index => :val_per_lang_per_prop_type
  property :definition, String, :required => true, :length => 255
  
  belongs_to :property_type
    property :property_type_id, Integer, :unique_index => :val_per_lang_per_prop_type
  
  # TODO: implement definitions_for_properties and factor out of PropertyDefintion
  
  # TODO: spec
  def self.definitions_for_property_id(property_id, language_code)
    query =<<-SQL
      SELECT pvd.value, pvd.definition
      FROM property_value_definitions pvd
        INNER JOIN property_types pt ON pvd.property_type_id = pt.id
        INNER JOIN property_definitions pd ON pt.id = pd.property_type_id
      WHERE pvd.language_code = ?
        AND pd.id = ?
    SQL
    
    definitions = {}
    repository.adapter.select(query, language_code, property_id).each do |record|
      definitions[record.value] = record.definition
    end
    definitions
  end
end
