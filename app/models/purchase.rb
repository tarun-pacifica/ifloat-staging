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
# === 1. Purchase One or More Products
#
# TODO: it may be prudent to e-mail support every time a complete parsing is not possible (as commission rides on it)
#       - in any case we need to e-mail a confirmation of the purchase (pretty-print response)
#
# === 2. Abandon Obsolete Purchases
#
# Run Purchase.obsolete.destroy! periodically. This marks all Purchases open for longer than OBSOLESCENCE_TIME as abandoned.
#
class Purchase
  include DataMapper::Resource
  
  OBSOLESCENCE_TIME = 24.hours
  
  property :id,               Serial
  property :created_at,       DateTime, :required => true, :default => proc { DateTime.now }
  property :completed_at,     DateTime
  property :response,         Object
  
  belongs_to :facility
  belongs_to :user, :required => false
  
  def self.obsolete
    all(:created_at.lt => OBSOLESCENCE_TIME.ago, :completed_at => nil)
  end
  
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
  
  def complete!(params)    
    self.response = Purchase.parse_response(params)
    self.completed_at = DateTime.now
    save
    self.response[:items].map { |item| item["reference"] }.compact.uniq
  end
end
