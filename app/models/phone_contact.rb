# = Summary
#
# See the Contact superclass.
#
class PhoneContact < Contact
  VARIANTS = %w(Landline Mobile Fax).to_set
  
  validates_within :variant, :set => VARIANTS
  validates_format :value, :with => /^\+?[\d ]{8,}$/
end
