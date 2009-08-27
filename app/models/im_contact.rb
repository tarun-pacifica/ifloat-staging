# = Summary
#
# See the Contact superclass.
#
class ImContact < Contact
  VARIANTS = ["AIM", "Facebook", "GG", "GTalk", "ICQ", "Jabber", "MSN", "MySpace", "QQ", "Skype", "Xfire", "Yahoo!"]
  
  validates_within :variant, :set => VARIANTS
end
