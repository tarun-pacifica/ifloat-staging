# = Summary
#
# An image, a logo, a specification PDF, a scanned document or any other form of self-contained data is recorded as an Asset. Assets are macroscopically organised by the Company they pertain to (defaulting to Pristine in ambiguous cases) and by a general 'bucket' designed to carve up the namespace. They can be associated with various other classes in the system via Attachment objects.
#
# Assets are named in the manner of the data blob's on-disk file name (which should always include the pertinent extension). These names are unique per-company, per-bucket.
#
# === Sample Data
#
# bucket:: 'products'
# name:: 'wilkers_31.jpg'
#
class Asset
  include DataMapper::Resource
  
  BUCKETS = %w(brand_logos category_images products property_icons)
  IMAGE_FORMAT = /\.(gif|jpeg|jpg|png|tif|tiff)$/
  NAME_FORMAT = /^([\w\-\.]+?)\.([a-z]{3,})$/
  STORE_KEYS = [:bucket, :name, :checksum, :file_path, :file_path_small, :file_path_tiny]
  
  property :id, Serial
  property :bucket, String, :required => true, :unique_index => :name_per_company_per_bucket
  property :name, String, :required => true, :length => 255, :format => NAME_FORMAT, :unique_index => :name_per_company_per_bucket
  property :pixel_size, String
  property :checksum, String
  
  belongs_to :company
    property :company_id, Integer, :required => true, :unique_index => :name_per_company_per_bucket
  has n, :attachments
  has n, :brands
  
  validates_within :bucket, :set => BUCKETS
  
  before :valid? do
    self.checksum ||= Digest::MD5.file(@file_path).hexdigest unless @file_path.nil?
  end
  
  before :save do
    store!
  end
  
  attr_writer :file_path
  attr_writer :file_path_small
  attr_writer :file_path_tiny
  
  def file_path(variant = nil)
    variant = "_#{variant}" unless variant.nil?
    instance_variable_get("@file_path#{variant}")
  end
  
  # TODO: spec
  def store!
    AssetStore.write(self) unless @file_path.nil?
    AssetStore.write(self, "small") unless @file_path_small.nil?
    AssetStore.write(self, "tiny") unless @file_path_tiny.nil?
  end
  
  def store_name(variant = nil)
    raise "unable to generate store_name without bucket, checksum (via file_path=) and name" if [bucket, checksum, name].any? { |v| v.nil? }
    variant = "-#{variant}" unless variant.nil?
    "#{checksum}#{variant}#{File.extname(name)}"
  end
  
  def store_names
    variants = [nil]
    variants += ["small", "tiny"] if bucket == "products" and name =~ IMAGE_FORMAT
    variants.map { |variant| store_name(variant) }
  end
  
  def url(variant = nil)
    AssetStore.url(self, variant)
  end
  
  # TODO: spec
  def urls_by_variant
    Hash[[:small, :tiny].map { |k| [k, url(k)] }]
  end
end
