# = Summary
#
# Any time a user chooses to add a Product to one of the global lists (i.e. shopping list), a PickedProduct is created. This object simply relates the user to a Product with a creation timestamp.
#
# = Processes
#
# === 1. Abandon Obsolete PickedProducts
#
# When destroying sessions, destroy any anonymous picked products whose IDs no longer appear in any session.
#
class PickedProduct
  include DataMapper::Resource
  
  GROUPS = {"buy_later" => "Future Buys", "buy_now" => "Basket", "compare" => "Compare List"}
  
  property :id,           Serial
  property :created_at,   DateTime, :default => proc { DateTime.now }
  property :group,        String,   :required => true
  property :cached_brand, String,   :required => true
  property :cached_class, String,   :required => true
  property :quantity,     Integer
  property :invalidated,  Boolean,  :required => true
  
  belongs_to :product
  belongs_to :user, :required => false
  
  validates_within :group, :set => GROUPS.keys
  
  def self.all_primary_keys
    query =<<-SQL
      SELECT DISTINCT c.reference AS cref, p.reference AS pref
      FROM picked_products pp
        INNER JOIN products p ON pp.product_id = p.id
        INNER JOIN companies c ON p.company_id = c.id
    SQL
    
    repository(:default).adapter.select(query).map { |record| [record.cref, record.pref] }
  end
  
  def orphaned_message
    "Discontinued #{cached_brand} #{cached_class} removed from your #{GROUPS[group]}."
  end
  
  def title_parts
    [cached_brand, cached_class]
  end
end
