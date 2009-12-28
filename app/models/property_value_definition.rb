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
  property :language_code, String, :required => true, :format => /^[A-Z]{3}$/
  property :value, String, :required => true
  property :definition, String, :required => true, :length => 255
  
  belongs_to :property_type
  
  validates_present :property_type_id
  validates_is_unique :value, :scope => [:property_type_id, :language_code]
end
