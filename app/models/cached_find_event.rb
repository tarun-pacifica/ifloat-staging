# = Summary
#
# This is a logger for each call to CachedFinds#create. It thus tracks all new find requests (and makes a note of whether they lead to actual creation or simple recall).
#
class CachedFindEvent
  include DataMapper::Resource
  
  property :id, Serial
  property :specification, String, :length => 255, :required => true
  property :recalled, Boolean, :required => true
  property :ip_address, IPAddress, :required => true
  property :created_at, DateTime, :default => proc { DateTime.now }
  
  
  def self.log!(specification, recalled, ip_address)
    create(:specification => specification, :recalled => recalled, :ip_address => ip_address)
  end
end