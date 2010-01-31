# = Summary
#
# Wherever a supplier / retailer assigns their own reference to a FacilityProduct, the system needs to be able to derive the original DefinitiveProduct reference from it. Thus a ProductMapping exists to define the reference for a DefinitiveProduct in terms of a Company.
#
# Note that, because the DefinitiveProduct system is deemed to have a level of granularity that is always >= that for a Company's set of FacilityProduct references, many DefinitiveProducts may point back to a single FacilityProduct but not vice versa. Thus looking up a price is always unambiguous (DP -> FP) but associating an imported inventory item with a definitive product in the first place (FP -> DP) can be a matter of compromise.
#
# === Sample Data
#
# reference:: 'AF11235'
#
class ProductMapping
  include DataMapper::Resource
  
  property :id, Serial
  property :reference, String, :required => true, :format => /^[A-Z_\d\-\.\/]+$/

  belongs_to :company
  belongs_to :product, :model => "DefinitiveProduct", :child_key =>[:definitive_product_id]
  
  validates_is_unique :definitive_product_id, :scope => [:company_id, :reference] # TODO: spec
end
