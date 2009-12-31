# = Summary
#
# See the Product superclass.
#
class FacilityProduct < Product
  belongs_to :facility, :required => false
  
  validates_present :facility_id
end
