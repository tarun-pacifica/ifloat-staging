# = Summary
#
# See the Contact superclass.
#
class EmailContact < Contact
  validates_absent :variant
  validates_format :value, :with => :email_address
  
  before :valid? do
    value.downcase! unless value.nil?
  end
end
