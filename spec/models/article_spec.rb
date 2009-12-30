require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Article do
  
  describe "creation" do
    before(:each) do
      @article = Article.new(:asset_id => 1, :blog_id => 1, :user_id => 1, :title => "FlyFishing", :body => "Lorem ipsum dolor.")
    end
    
    it "should succeed with valid data" do
      @article.should be_valid
    end
    
    it "should succeed without an asset" do
      @article.asset = nil
      @article.should be_valid
    end
    
    it "should fail without a blog" do
      @article.blog = nil
      @article.should_not be_valid
    end
    
    it "should fail without a user" do
      @article.user = nil
      @article.should_not be_valid
    end
    
    it "should fail without a title" do
      @article.title = nil
      @article.should_not be_valid
    end
    
    it "should fail without a body" do
      @article.body = nil
      @article.should_not be_valid
    end
  end
  
  describe "destruction" do
    it "should destroy any attached image" do
      article = Article.create(:blog_id => 1, :user_id => 1, :title => "FlyFishing", :body => "Lorem ipsum dolor.")
      article.asset = Asset.create(:company_id => 1, :bucket => "articles", :name => "fishy.jpg")
      asset_id = article.asset.id
      article.destroy
      Asset.get(asset_id).should == nil
    end
  end
  
  describe "batch image retrieval" do
    before(:all) do
      @blog = Blog.create(:company_id => 1, :user_id => 1, :name => "fishing")
      @articles = %w(FlyFishing NightFishing ComplimentFishing).map do |title|
        article = @blog.articles.create(:user_id => 1, :title => title, :body => "Lorem ipsum dolor.")
        article.save_image("spec/assets/cube.jpg", "cube.jpg") unless title == "FlyFishing"
        article
      end
    end
    
    after(:all) do
      @articles.each { |a| a.destroy }
      @blog.destroy
    end
    
    it "should retrieve assets only for the specified articles" do
      Article.images(@articles[0..1]).size.should == 1
    end
  end
  
  describe "image saving" do
    before(:all) do
      @blog = Blog.create(:company_id => 1, :user_id => 1, :name => "fishing")
      @article = @blog.articles.create(:user_id => 1, :title => "FlyFishing", :body => "Lorem ipsum dolor.")
      
      @jpg_path = "spec/assets/cube.jpg"
      @png_path = "spec/assets/monkey.png"
      @png_name = File.basename(@png_path)
    end
    
    after(:all) do
      @article.destroy
      @blog.destroy
    end
    
    it "should fail with an unsaved Article" do
      article = Article.new(:user_id => 1, :title => "FlyFishing", :body => "Lorem ipsum dolor.")
      proc { article.save_image(@png_path, @png_name) }.should raise_error
    end
    
    it "should create an image belonging to the parent blog's company and the 'articles' bucket" do
      @article.save_image(@png_path, @png_name).should == true
      @article.asset.company_id.should == 1
      @article.asset.bucket.should == "articles"
    end
    
    it "should derive an image name of the form article_#.png for a source .png file name" do
      @article.save_image(@png_path, @png_name).should == true
      @article.asset.should_not == nil
      @article.asset.name.should == "article_#{@article.id}.png"
    end
    
    it "should derive an image name of the form article_#.jpg for an unparseable source file name" do
      @article.save_image(@jpg_path, "sillyname").should == true
      @article.asset.should_not == nil
      @article.asset.name.should == "article_#{@article.id}.jpg"
    end
    
    it "should destroy any existing image" do
      @article.save_image(@png_path, @png_name).should == true
      asset_id = @article.asset.id
      @article.save_image(@png_path, @png_name).should == true
      Asset.get(asset_id).should == nil
    end
  end
  
end