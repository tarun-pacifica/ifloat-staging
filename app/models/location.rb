# = Summary
#
# A Location object serves the common need for a record representing a physical region / address. It stores actual addresses as an un-parsed piece of text (which could be format checked in future using the recorded country code if needed). It also tracks, where available, both GPS co-ordinates and global location numbers (GLN13s).
#
# === Sample Data
#
# country_code:: 'GBR'
# postal_address:: 'The Rise\nTrebuchetRoad\nMiddlesex...'
# gps_coordinates:: '46.854791x10.469842'
# gln_13:: '0811234001523'
#
class Location
  include DataMapper::Resource
  
  property :id, Serial
  property :country_code, String, :required => true, :format => /^[A-Z]{3}$/
  property :postal_address, String, :length => 255
  property :gps_coordinates, String, :format => /^[\d\.]+x[\d\.]+$/ # TODO: verify format
  property :gln_13, Integer
  
  belongs_to :user, :required => false
  
  validates_with_block :gln_13 do
    if gln_13.nil? then true
    else
      check_digit = gln_13 % 10
      gln_13_checksum(gln_13) == check_digit || [false, "GLN-13 should pass the GLN-13 checksum"]
    end
  end
  
  
  private
  
  # 0061414000017 => 7
  # 1. knock off the check digit
  # 2. checksum += 3 * (2nd, 4th, 6th, ...) digits
  # 3. checksum += 1 * (1st, 3rd, 5th, ...) digits
  # 4. return integer needed to round checksum up to nearest multiple of 10
  def gln_13_checksum(gln)
    checksum = 0
    1.upto(12) do |i|
      shifted_gln = gln / (10 ** i)
      break if shifted_gln == 0
      checksum += (i.odd? ? 3 : 1 ) * (shifted_gln % 10)
    end
    (10 - checksum) % 10
  end
end
