# = Summary
#
# See the Product superclass.
#
class UserProduct < Product
  belongs_to :definitive_product, :child_key => [:definitive_product_id]
  belongs_to :location
  belongs_to :parent, :class_name => "UserProduct", :child_key => [:parent_id]
  belongs_to :purchase
  belongs_to :user
  
  validates_present :definitive_product_id, :user_id
end
