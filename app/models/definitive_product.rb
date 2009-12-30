# = Summary
#
# See the Product superclass.
#
# In order to aid with quality control (particularly in the case where a DefinitiveProduct is mostly / entirely inferred from retailer information), Products carry a 'review_stage' flag which helps with data preparation in grouping products together that have had the same level of editorial attention. <em>Note that this simple revision number could become a foreign key out to a revisions schema to power more complex workflows.</em>
#
class DefinitiveProduct < Product
  property :review_stage, Integer, :required => true, :default => 0
  
  belongs_to :company
  has n, :mappings, :model => "ProductMapping", :child_key => [:definitive_product_id]
  has n, :product_relationships, :child_key => [:definitive_product_id]
  has n, :user_products
  
  validates_is_unique :reference, :scope => [:company_id]
end
