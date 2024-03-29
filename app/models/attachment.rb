# = Summary
#
# Assets may be attached to Products. Attachment objects track the nature of any such relationship. More specifically, the Asset is said to serve a 'role' with respect to the Product. See ROLES for a complete list of allowed values.
#
# In order to support the import process, the import 'sequence number' must be recorded in the Attachment. The Product image Attachment with the lowest sequence number (for a given product) has special significance in indicating the asset that should be used as that product's master image.
#
# === Sample Data
#
# role:: 'image'
# sequence_number:: 1
#
class Attachment
  include DataMapper::Resource
  
  ROLES = {
    "image"              => "Image",
    "image_hi_res"       => "High Resolution Image",
    "brochure"           => "Brochure",
    "specification"      => "Specification Set",
    "dimensions"         => "Dimension Set",
    "installation"       => "Installation Guide",
    "operation"          => "Operation Guide",
    "maintenance"        => "Maintenance Guide",
    "parts"              => "Parts Listing",
    "review"             => "Review",
    "user_experience"    => "User Experience Review",
    "safety_data_sheet"  => "Safety Data Sheet",
    "product_data_sheet" => "Product Data Sheet"
  }
  
  property :id, Serial
  property :role, String, :unique_index => :seq_num_per_prod_per_role
  property :sequence_number, Integer, :required => true, :unique_index => :seq_num_per_prod_per_role
  
  belongs_to :asset
  belongs_to :product
    property :product_id, Integer, :required => true, :unique_index => :seq_num_per_prod_per_role
  
  validates_within :role, :set => ROLES.keys
  
  def self.product_role_assets(product_ids)
    return [] if product_ids.empty?
    
    attachments = Attachment.all(:product_id => product_ids, :order => [:sequence_number])
    
    asset_ids = attachments.map { |attachment| attachment.asset_id }
    
    assets_by_id = {}
    Asset.all(:id => asset_ids).each do |asset|
      assets_by_id[asset.id] = asset
    end
    
    assets_by_role_by_product_id = {}
    attachments.each do |attachment|
      assets_by_role = (assets_by_role_by_product_id[attachment.product_id] ||= {})
      assets = (assets_by_role[attachment.role] ||= [])      
      assets << assets_by_id[attachment.asset_id]
    end
    product_ids.each do |product_id|
      assets_by_role_by_product_id[product_id] = {} unless assets_by_role_by_product_id.has_key?(product_id)
    end
    assets_by_role_by_product_id
  end
end
