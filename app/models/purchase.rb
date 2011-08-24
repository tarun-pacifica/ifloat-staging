# = Summary
#
# Completed transactions on partner sites are tracked by the Purchase class. Each time a trackback is completed for a user with a session history (with an event inside the Facility's TTL), a Purchase is created linked with the Facility, the Session and the User who is making it (if known).
#
# The response data returned by a partner's site is parsed and stored as a structured Hash.
#
# === Sample Data
#
# ip_address:: "10.0.0.1"
# response:: {:items => [...], :currency => "GBP", :reference => "abcd1234", :total => "22.50"}
#
class Purchase
  include DataMapper::Resource
  
  property :id,           Serial
  property :completed_at, DateTime,  :required => true, :default => proc { DateTime.now }
  property :ip_address,   IPAddress, :required => true
  property :response,     Object,    :required => true
  
  belongs_to :facility
  belongs_to :session, :model => "Merb::DataMapperSessionStore", :child_key => [:session_id]
  belongs_to :user, :required => false
  
  # TODO: spec
  def self.all_facility_primary_keys
    query =<<-SQL
      SELECT DISTINCT c.reference AS cref, f.name AS fname
      FROM purchases p
        INNER JOIN facilities f ON p.facility_id = f.id
        INNER JOIN companies c ON f.company_id = c.id
    SQL
    
    repository(:default).adapter.select(query).map { |record| [record.cref, record.fname] }
  end
  
  def self.parse_response(params)
    parsed_data = {:items => []}
    
    params.each do |key, value|
      case key
      when "currency", "reference", "total"
        parsed_data[key.to_sym] = value
      when /^item_\d+$/
        item = {}
        Merb::Parse.unescape(value).split("&").map do |pair|
          key, value = pair.split("=")
          item[key] = Merb::Parse.unescape(value) unless value.nil?
        end
        parsed_data[:items] << item
      end
    end
    
    parsed_data
  end
  
  # TODO: spec
  def cookie_date
    entity = SessionEvent.last(:session_id => session_id, :created_at.lt => completed_at) || session
    entity.nil? ? nil : entity.created_at
  end
end
