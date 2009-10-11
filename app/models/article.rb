# = Summary
#
# Articles are single blocks of text with an optional attached image. They belong to a User (the author) and a Blog. The schema allows an Article and it's parent Blog to belong to different Users - allowing for contributing authors.
#
# === Sample Data
#
# title:: 'Fishing for Compliments'
# body:: 'Lorem ipsum dolor sit amet, consectetur adipisicing elit.'
#
class Article
  include DataMapper::Resource
  
  property :id, Serial
  property :title, String, :nullable => false
  property :body, Text, :nullable => false
  property :created_at, DateTime, :default => proc { DateTime.now }
  
  belongs_to :asset
  belongs_to :blog
  belongs_to :user
  
  validates_present :blog_id
  validates_present :user_id
  
  before :destroy do
	  asset.destroy unless asset.nil?
  end
  
  def self.images(articles)
    Asset.all(:id => articles.map { |a| a.asset_id }).hash_by(:id)
  end
  
  def save_image(file_path, original_name)
    raise "cannot set the image on an unsaved Article" if new_record?
    
    extension = (original_name =~ /\.([A-Za-z]{3,})$/ ? $1.downcase : "jpg")
    asset.destroy unless asset.nil?
    self.asset = Asset.create(:company_id => blog.company_id, :bucket => "articles", :name => "article_#{id}.#{extension}", :file_path => file_path)
    save
  end
end
