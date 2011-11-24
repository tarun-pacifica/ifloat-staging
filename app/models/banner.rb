# = Summary
#
# A Banner is a configurable advertising unit used to provide affiliate links based on an image, a location on the site and a link out. Custom HTML can also be provided replacing both the image and the link.
# 
# 
# === Sample Data
# 
# description:: 'Big Boats'
# link_url:: 'http://www.bigboats.co.uk?affiliate_id=42'
# location:: 'header'
# height:: 400
# width:: 600
#
class Banner
  include DataMapper::Resource
  
  LOCATIONS = %w(header under-basket under-basket-2)
  
  property :id, Serial
  
  property :description, String, :length => 255, :required => true
  property :link_url,    String, :length => 255
  property :custom_html, Text
  
  property :location,    String,  :length => 255, :required => true
  property :height,      Integer, :default => 0
  property :width,       Integer, :default => 0
  
  belongs_to :asset
    property :asset_id,  Integer, :required => false
  
  validates_within :location, :set => LOCATIONS
  
  def html
    custom_html || (link_url.nil? ? image_html : link_html)
  end
  
  
  private
  
  def image_html
     "<img src=\"#{asset.url}\" border=\"0\" width=\"#{width}\" height=\"#{height}\" />"
  end
  
  def link_html
    "<a href=\"#{link_url}\" target=\"new\"> #{image_html} </a>"
  end
end
