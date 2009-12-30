# = Summary
#
# Translation is a very simple class that allows string values to be translated into an arbitrary number of languages. In it's current incarnation, it is used to present localized, friendly versions of PropertyDefinition names.
#
# === Sample Data
#
# language_code:: 'FRA'
# value:: 'aspect:couleur'
#
class Translation
  include DataMapper::Resource
  
  property :id, Serial
  property :language_code, String, :required => true, :format => /^[A-Z]{3}$/
  property :value, Text, :required => true, :lazy => false
  
  belongs_to :property_definition
  
  validates_is_unique :language_code, :scope => [:property_definition_id]
end
