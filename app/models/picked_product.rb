# = Summary
#
# Any time a user chooses to add a Product to one of the global lists (i.e. shopping list), a PickedProduct is created. This object simply relates the user to a Product with a creation timestamp.
#
# = Processes
#
# === 1. Abandon Obsolete PickedProducts
#
# Run PickedProduct.obsolete.destroy! periodically. This destroys anonymous PickedProducts created longer than the Merb session TTL ago.
#
class PickedProduct
  include DataMapper::Resource
  
  GROUPS = %w(buy_later buy_now compare).to_set
  
  property :id,           Serial
  property :created_at,   DateTime, :default => proc { DateTime.now }
  property :group,        String,   :required => true
  property :cached_brand, String,   :required => true
  property :cached_class, String,   :required => true
  property :invalidated,  Boolean,  :required => true
  
  belongs_to :product
  belongs_to :user, :required => false
  
  validates_within :group, :set => GROUPS
  
  def self.obsolete
    all(:user_id => nil, :accessed_at.lt => Merb::Config[:session_ttl].ago)
  end
  
  # TODO: spec
  def self.all_primary_keys
    query =<<-SQL
      SELECT DISTINCT c.reference AS cref, p.reference AS pref
      FROM picked_products pp
        INNER JOIN products p ON pp.product_id = p.id
        INNER JOIN companies c ON p.company_id = c.id
    SQL
    
    repository(:default).adapter.select(query).map { |record| [record.cref, record.pref] }
  end
  
  # TODO: spec
  def title_parts
    [cached_brand, cached_class]
  end
end
