# = Summary
#
# In order to support synonyms / acronyms and other find term variations, AssociatedWord objects match an associated word to one or more potential property values.
#
# In order to prevent massive import dependency, these associations are loaded by the indexer and hook into the existing find-matching machinery.
#
# === Sample Data
#
# word:: 'man'
# implied_by:: {'clothing:maturity'.ID => 'adult', 'clothing:gender'.ID => 'male'}
#
class AssociatedWord
  include DataMapper::Resource
  
  property :id,         Serial
  property :word,       Text,   :lazy => false, :required => true
  property :implied_by, Object, :lazy => false, :required => true
  
  validates_with_block :implied_by, :if => :implied_by do
    implied_by.is_a?(Hash) and implied_by.keys.all? { |k| k.is_a?(Integer) } and implied_by.values.all? { |v| v.is_a?(String) and v.size > 0 } || [false, "Rule should be a hash of words by property ID"]
  end
end
