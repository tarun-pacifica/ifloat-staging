# = Summary
#
# Articles are single blocks of text with an optional attached image. They belong to a User (the author). As well as one off review pieces or essays, a suite of Articles may belong to a Blog. The schema allows an Article and it's parent Blog to belong to different Users - allowing for contributing authors.
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
  
  validates_present :user_id
  
  # TODO: spec
  def self.images(articles)
    images_by_asset_id = {}
    Asset.all(:id => articles.map { |a| a.asset_id }).each do |asset|
      images_by_asset_id[asset.id] = asset
    end
    images_by_asset_id
  end
  
  # TODO: spec
  def save_image(file_path, original_name)
    raise "cannot set the image on an unsaved Article" if new_record?
    
    extension = (original_name =~ /\.([A-Za-z]{3,})$/ ? $1.downcase : "jpg")
    asset.destroy unless asset.nil?
    self.asset = Asset.create(:company => blog.company, :bucket => "articles", :name => "article_#{id}.#{extension}", :file_path => file_path)
    save
  end
end
