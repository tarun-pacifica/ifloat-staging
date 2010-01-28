# = Summary
#
# Any time a user chooses to either 'add to basket' or 'buy later', a FuturePurchase (with deferred = false / true, respectively) is created. This object simply relates the user to a DefinitiveProduct with a creation timestamp.
#
# TODO: add process for cleaning up expired FuturePurchases (those no longer mentioned by a CF - see CF.obsolete)
#       note that we shouldn't auto-anonymize FPs as they are good for all time (in theory)
class FuturePurchase
  include DataMapper::Resource
  
  property :id, Serial
  property :created_at, DateTime, :default => proc { DateTime.now }
  property :deferred, Boolean, :required => true
  
  belongs_to :product, :model => "DefinitiveProduct", :child_key =>[:definitive_product_id]
  belongs_to :user, :required => false
  
  validates_is_unique :definitive_product_id, :scope => [:user_id], :unless => proc { |purchase| purchase.user_id.nil? }
  
  # TODO: spec
  def self.all_definitive_product_primary_keys
    query =<<-SQL
      SELECT DISTINCT c.reference AS cref, p.reference AS pref
      FROM future_purchases fp
        INNER JOIN products p ON fp.definitive_product_id = p.id
        INNER JOIN companies c ON p.company_id = c.id
    SQL
    
    repository(:default).adapter.select(query).map { |record| [record.cref, record.pref] }
  end
end
