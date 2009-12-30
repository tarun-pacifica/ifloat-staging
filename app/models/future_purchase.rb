# = Summary
#
# Any time a user chooses to either 'add to basket' or 'buy later', a FuturePurchase (with deferred = false / true, respectively) is created. This object simply relates the user to a DefinitiveProduct with a creation timestamp.
#
class FuturePurchase
  include DataMapper::Resource
  
  property :id, Serial
  property :created_at, DateTime, :default => proc { DateTime.now }
  property :deferred, Boolean, :required => true
  
  belongs_to :product, :model => "DefinitiveProduct", :child_key =>[:definitive_product_id]
  belongs_to :user, :required => false
  
  validates_is_unique :definitive_product_id, :scope => [:user_id], :unless => proc { |purchase| purchase.user_id.nil? }
end
