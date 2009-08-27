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
    
    it "should succeed without a blog" do
      @article.blog = nil
      @article.should be_valid
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
  
end