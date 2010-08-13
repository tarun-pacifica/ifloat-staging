# = Summary
#
# See the Contact superclass.
#
class PhoneContact < Contact
  VARIANTS = %w(Landline Mobile Fax)
  
  validates_within :variant, :set => VARIANTS
  validates_format_of :value, :with => /^\+?[\d ]{8,}$/
end
