# = Summary
#
# See the Product superclass.
#
class UserProduct < Product
  belongs_to :definitive_product, :child_key => [:definitive_product_id]
  belongs_to :location, :required => false
  belongs_to :parent, :model => "UserProduct", :child_key => [:parent_id], :required => false
  belongs_to :purchase, :required => false
  belongs_to :user
end
