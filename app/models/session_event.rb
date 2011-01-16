# = Summary
#
# Used to audit user histories by session.
#
class SessionEvent
  include DataMapper::Resource
  
  property :id,         Serial
  property :type,       String,    :required => true, :set => %w(GET)
  property :value,      Text,      :required => true
  property :ip_address, IPAddress, :required => true
  property :created_at, DateTime,  :default => proc { DateTime.now }
  
  belongs_to :session, :model => "Merb::DataMapperSessionStore", :child_key => [:session_id]
end
