# = Summary
#
# The Message class provides an inbox for messages bound for a particular User (the only parent model at the moment).
#
# === Sample Data
#
# message:: 'Something happened to your basket.'
#
class Message
  include DataMapper::Resource
  
  property :id,         Serial
  property :value,      Text, :required => true
  property :created_at, DateTime, :default => proc { DateTime.now }
  
  belongs_to :user
end
