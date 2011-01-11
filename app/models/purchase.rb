# = Summary
#
# The main purchasing workflow of the application is tracked by the Purchase class. Each time a new outbound purchasing cycle begins, a Purchase object is created and the involved InventoryProduct references are recorded. The Purchase is linked with the Facility from which the purchasing process is about to take place and the User who is making it (if known).
#
# The response data returned by a partner's site is parsed and stored as a structured Hash.
#
# Timestamps are recorded at both the point of creation / posting (created_at) and the point of completion (completed_at). Also noted is whether the completion was due to a successful Purchase or a system auto-expiry (abandoned).
#
# === Sample Data
#
# product_refs:: ['ABCD12345', 'FGGH43256']
# response_data:: {:company => 'GBR-12345', :reference => 'ABCD1234', ...}
#
# = Processes
#
# === 1. Abandon Obsolete Purchases
#
# Run Purchase.obsolete.destroy! periodically. This treats all Purchases open for longer than OBSOLESCENCE_TIME as abandoned.
#
class Purchase
  include DataMapper::Resource
  
  OBSOLESCENCE_TIME = 24.hours
  
  property :id,           Serial
  property :created_at,   DateTime,  :required => true, :default => proc { DateTime.now }
  property :created_ip,   IPAddress, :required => true # TODO: update spec
  
  property :response,     Object
  property :completed_at, DateTime
  property :completed_ip, IPAddress # TODO: update spec
  
  belongs_to :facility
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
  
  def self.obsolete
    all(:created_at.lt => OBSOLESCENCE_TIME.ago, :completed_at => nil)
  end
  
  # TODO: spec
  def self.parse_response(params)
    parsed_data = {:items => []}
    
    params.each do |key, value|
      case key
      when "currency", "reference", "total"
        parsed_data[key] = value
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
  def complete!(parsed_response, ip_address)    
    self.response = parsed_response
    self.completed_at = DateTime.now
    self.completed_ip = ip_address
    save
    self.response[:items].map { |item| item["reference"] }.compact.uniq
  end
end
