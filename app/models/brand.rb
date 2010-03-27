# = Summary
#
# Brands are uniquely named per company and may carry a logo and primary URL.
#
# === Sample Data
#
# primary_url:: 'www.mybrand.com'
#
class Brand
  include DataMapper::Resource
  
  property :id, Serial
  property :name, String, :required => true, :length => 255, :unique_index => :name_per_company
  property :primary_url, String, :length => 255
  
  belongs_to :asset
  belongs_to :company
    property :company_id, Integer, :unique_index => :name_per_company
    
  before :destroy do
	  asset.destroy unless asset.nil?
  end
  
  # TODO: spec
  # TODO: if needed, augment to take a list of names_by_company_id to support brand namespace clashes
  def self.logos(names)
    Asset.all("brands.name" => names)
  end
end
