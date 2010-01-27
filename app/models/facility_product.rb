# = Summary
#
# Imported product listings from retailer's e-stores (and any other facility stocking products) are tracked as FacilityProducts. The price of such products is currently tracked in an ultra-simple manner pending the need for both multi-currency-per-facility and point-in-time aware pricing
#
class FacilityProduct
  include DataMapper::Resource
  
  CURRENCY_FORMAT = /^[A-Z]{3}$/
  REFERENCE_FORMAT = /^[A-Z_\d\-\.\/]+$/
  
  property :id, Serial
  property :reference, String, :format => REFERENCE_FORMAT, :required => true
  property :price,     BigDecimal, :precision => 15, :scale => 3, :required => true
  property :currency,  String, :format => CURRENCY_FORMAT, :required => true
  
  belongs_to :facility
end
