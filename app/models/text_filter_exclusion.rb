# = Summary
#
# See the Filter class.
#
class TextFilterExclusion
  include DataMapper::Resource
  
  property :id, Serial
  property :value, Text, :nullable => false
  
  belongs_to :text_filter, :child_key => [:text_filter_id]
  
  validates_present :text_filter_id
  validates_is_unique :value, :scope => [:text_filter_id]
end