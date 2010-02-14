# = Summary
#
# Wherever a supplier / retailer assigns their own reference to a FacilityProduct, the system needs to be able to derive the original Product from it. Thus a ProductMapping exists to define the reference for a Product in terms of a Company.
#
# Note that, because the Product system is deemed to have a level of granularity that is always >= that for a Company's set of FacilityProduct references, many Products may point back to a single FacilityProduct but not vice versa. Thus looking up a price is always unambiguous (Product -> FacilityProduct) but associating an imported inventory item with an internal product in the first place (FacilityProduct -> Product) is a matter for compromise.
#
# === Sample Data
#
# reference:: 'AF11235'
#
class ProductMapping
  include DataMapper::Resource
  
  property :id, Serial
  property :reference, String, :required => true, :format => /^[A-Z_\d\-\.\/]+$/, :unique_index => :prod_per_company_per_ref

  belongs_to :company
    property :company_id, Integer, :unique_index => :prod_per_company_per_ref
  belongs_to :product
    property :product_id, Integer, :unique_index => :prod_per_company_per_ref
end
