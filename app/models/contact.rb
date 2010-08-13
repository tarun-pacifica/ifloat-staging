# = Summary
#
# The Contact subclasses allow the application to track contact information for a given User. <b>Note that Contact itself is an abstract superclass and should never be created directly.</b>
#
# The subclasses are...
#
# EmailContact:: value is an email address, variant must be nil
# ImContact:: value is an instant messaging identity, variant must be one of ImContact::VARIANTS
# PhoneContact:: value is at least 8 characters long containing numbers and spaces and optionally starting with a '+', variant must be one of PhoneContact::VARIANTS
#
# Physical addresses are dealt with directly using the Location class rather than a Contact subclass.
#
class Contact
  include DataMapper::Resource
  
  property :id, Serial
  property :type, Discriminator
  property :variant, String
  property :value, String, :required => true, :length => 255
  
  belongs_to :user
    property :user_id, Integer, :required => true # TODO: investigate why inherited models require this
    
  validates_with_block :type do
    (self.class != Contact and self.kind_of?(Contact)) || [false, "Type must be a sub-class of Contact"]
  end
end
