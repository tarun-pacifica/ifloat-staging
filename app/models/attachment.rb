# = Summary
#
# Assets may be attached to CachedFinds and Products. Attachment objects track the nature of any such relationship. More specifically, the Asset is said to serve a 'role' with respect to the CachedFind etc... See ROLES for a complete list of allowed values.
#
# In order to support the import / export process (particularly for DefinitiveProducts), the import 'sequence number' must be recorded in the Attachment. The Product image Attachment with the lowest sequence number (for a given product) has special significance in indicating the asset that should be used for the list / gallery view.
#
# === Sample Data
#
# role:: 'image'
# sequence_number:: 1
#
class Attachment
  include DataMapper::Resource
  
  ROLES = ["image", "image_hi_res", "brochure", "specification", "dimensions",
           "installation", "operation", "maintenance", "parts", "review",
           "user_experience", "safety_data_sheet"]
  
  property :id, Serial
  property :role, String
  property :sequence_number, Integer, :nullable => false
  
  belongs_to :asset
  belongs_to :cached_find
  belongs_to :product
  
  validates_present :asset_id
  
  validates_with_method :validate_parentage
  def validate_parentage
    ([cached_find_id, product_id].compact.size == 1) ||
      [false, "should belong to either a CachedFind or a Product"]
  end
  
  validates_within :role, :set => ROLES
  validates_is_unique :sequence_number, :scope => [:cached_find_id, :product_id, :role]
  
  # TODO: spec
  def self.product_role_assets(product_ids, include_chains = true)
    return [] if product_ids.empty?
        
    attachments = Attachment.all(:product_id => product_ids, :order => [:sequence_number])

    asset_ids = attachments.map { |attachment| attachment.asset_id }
    
    assets_by_id = {}
    Asset.all(:id => asset_ids).each do |asset|
      assets_by_id[asset.id] = asset
    end
    
    asset_chains_by_id = (include_chains ? Asset.chains_by_id(asset_ids) : {})
    
    assets_by_role_by_product_id = {}
    attachments.each do |attachment|
      assets_by_role = (assets_by_role_by_product_id[attachment.product_id] ||= {})
      assets = (assets_by_role[attachment.role] ||= [])      
      assets << assets_by_id[attachment.asset_id]
      assets.push(*(asset_chains_by_id[attachment.asset_id] || []))
    end
    product_ids.each do |product_id|
      assets_by_role_by_product_id[product_id] = {} unless assets_by_role_by_product_id.has_key?(product_id)
    end
    assets_by_role_by_product_id
  end
end
