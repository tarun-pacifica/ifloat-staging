# = Summary
#
# See the Contact superclass.
#
class PhoneContact < Contact
  VARIANTS = ["Landline", "Mobile", "Fax"]
  
  validates_within :variant, :set => VARIANTS
  validates_format :value, :with => /^\+?[\d ]{8,}$/
end
