# = Summary
#
# See the Contact superclass.
#
class EmailContact < Contact
  validates_absence_of :variant
  validates_format_of :value, :with => :email_address
  
  before :valid? do
    value.downcase! unless value.nil?
  end
end
