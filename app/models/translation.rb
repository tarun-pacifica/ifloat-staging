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
  property :language_code, String, :required => true, :format => /^[A-Z]{3}$/, :unique_index => :lang_per_prop
  property :value, Text, :required => true, :lazy => false
  
  belongs_to :property_definition
    property :property_definition_id, Integer, :unique_index => :lang_per_prop
end
