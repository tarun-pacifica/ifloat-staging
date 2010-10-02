# = Summary
#
# In order to support synonyms / acronyms and other find term variations, AssociatedWord objects match an associated word to one or more potential property values.
#
# In order to prevent massive import dependency, these associations are loaded by the indexer and hook into the existing find-matching machinery.
#
# === Sample Data
#
# word:: 'man'
# rules:: {'clothing:maturity'.ID => 'adult', 'clothing:gender'.ID => 'male'}
#
class AssociatedWord
  include DataMapper::Resource
  
  property :id,    Serial
  property :word,  Text,   :lazy => false, :required => true
  property :rules, Object, :lazy => false, :required => true
  
  validates_with_block :rules, :if => :rules do
    rules.is_a?(Hash) and (rules.keys + rules.values).all? { |s| s.is_a?(String) and s.size > 1 } ||
      [false, "Rule should be a hash of words by property name"]
  end
end
