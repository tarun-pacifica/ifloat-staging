# = Summary
#
# An image, a logo, a specification PDF, a scanned document or any other form of self-contained data is recorded as an Asset. Assets are macroscopically organised by the Company they pertain to (defaulting to Pristine in ambiguous cases) and by a general 'bucket' designed to carve up the namespace. They can be associated with various other classes in the system via Attachment objects.
#
# Assets are named in the manner of the data blob's on-disk file name (which should always include the pertinent extension). Note that Asset names form a unique set per bucket regardless of the Company they belong to.
#
# Assets also have a description, which may be used for captions / hover-bubbles.
#
# Assets can form 'chains'. This feature is used to present logically grouped and sequenced assets together. These chains might include time-lapsed images, images of the same object from different perspectives or a set of documents that form an ordered bundle. Note that a convention has been adopted whereby, if the Asset's name ends in a triple-underscore followed by a number (plus the relevant extension, of course), the asset is considered a link in a chain and at the position indicated by that number.
#
# Image assets may carry a view specifier that indicates the angle from which the image is taken. Values of 'top', 'bottom', 'left', 'right', 'front', 'back' cover the six faces of a projected cube. Values like 'top-left' then allow for the edges of that same cube. Finally, the vertices of the cube are described by values like 'top-left-front'. This up-to-three-face specification allows for 6 faces + 12 edges + 8 corners = 26 perspectives to be specified in a quick and intuitive manner. See CUBIC_VIEWS for a complete list of allowed values. <em>Note that this view support is intended for future use as the necessarry data entry is deemed too labour-intensive for phase 1.</em>
#
# An Asset's provenance can be recorded in a free-form source notes field which might contain (for example) the originating URL.
#
# === Sample Data
#
# bucket:: 'products'
# name:: 'wilkers_31.jpg'
# description:: 'Side view of the Wilkers 31 speedboat.'
# view:: 'top-left'
# source_notes:: 'Scanned from Wilkers May 2008 catalogue (page 21).'
#
class Asset
  include DataMapper::Resource
  
  CUBIC_VIEWS = [
    nil,
    # faces
    "top", "bottom", "left", "right", "front", "back",
    # edges
    "top-left", "top-right", "top-front", "top-back",
    "bottom-left", "bottom-right", "bottom-front", "bottom-back",
    "left-front", "left-back", "right-front", "right-back",
    # corners
    "top-left-front", "top-left-back",
    "top-right-front", "top-right-back",
    "bottom-left-front", "bottom-left-back",
    "bottom-right-front", "bottom-right-back"
  ]
  
  BUCKETS = %w(articles blogs products property_icons)
  NAME_FORMAT = /^([\w\-\.]+?)(___(\d+))?\.([a-z]{3,})$/
  
  property :id, Serial
  property :bucket, String, :nullable => false
  property :name, String, :nullable => false, :size => 255, :format => NAME_FORMAT
  property :description, String, :size => 255
  property :view, String
  property :source_notes, String, :size => 255
  property :chain_id, Integer
  property :chain_sequence_number, Integer
  property :checksum, String
  
  belongs_to :company
  has n, :attachments
  
  validates_present :company_id
  validates_within :bucket, :set => BUCKETS
  validates_is_unique :name, :scope => [:company_id, :bucket] # TODO: spec ??
  validates_within :view, :set => CUBIC_VIEWS
  
  validates_with_block :chain_id do
    chain_id.nil? || Asset.get(chain_id) || ["false", "should be the ID of an existing Asset"]
  end
  
  validates_absent :chain_sequence_number, :if => proc { |asset| asset.chain_id.nil? }
  validates_present :chain_sequence_number, :if => proc { |asset| not asset.chain_id.nil? }
  validates_is_unique :chain_sequence_number, :scope => [:chain_id], :allow_nil => true
  
  # TODO: spec
  before :valid? do
    root_name, chain_seq_num = self.class.parse_chain(name)
    unless chain_seq_num > 1
      root_asset = Asset.first(:bucket => bucket, :name => root_name)
      unless root_asset.nil?
        self.chain_id = root_asset.id 
        self.chain_sequence_number = chain_seq_num
      end
    end
  end
  
  # TODO: spec
  before :save do
    AssetStore.write(self) if @file_write
    @file_write = false
  end
  
  # TODO: spec
  def self.chains_by_id(asset_ids)
    asset_chains_by_id = {}
    Asset.all(:chain_id => asset_ids, :order => [:chain_sequence_number]).each do |asset|
      asset_chain = (asset_chains_by_id[asset.chain_id] ||= [])
      asset_chain << asset
    end
    asset_chains_by_id
  end
  
  # TODO: spec
  def self.parse_chain(name)
    name =~ NAME_FORMAT ? ["#{$1}___1.#{$4}", $3.to_i] : nil
  end
  
  # TODO: spec
  attr_reader :file_path
  def file_path=(value)
    self.checksum = Digest::MD5.file(value).hexdigest unless attribute_dirty?(:checksum)
    @file_path = value
    @file_write = true
  end
  
  # TODO: spec
  def store_name
    raise "unable to generate store_name without bucket, checksum (via file_path=) and name" if [bucket, checksum, name].any? { |v| v.nil?}
    "#{checksum}#{File.extname(name)}"
  end
  
  # TODO: spec
  def url
    AssetStore.url(self)
  end
end
