require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Blog do

  describe "creation" do   
    before(:each) do
      @blog = Blog.new(:company_id => 1,
                       :user_id => 1,
                       :name => "michael_jackson",
                       :description => "Lorem ipsum dolor.",
                       :email => "mj@example.com",
                       :primary_url => "www.example.com")
    end
    
    it "should succeed with valid data" do
      @blog.should be_valid
    end
    
    it "should fail without a company" do
      @blog.company = nil
      @blog.should_not be_valid
    end
    
    it "should fail without a user" do
      @blog.user = nil
      @blog.should_not be_valid
    end
    
    it "should fail without a name" do
      @blog.name = nil
      @blog.should_not be_valid
    end
    
    it "should succeed without a description" do
      @blog.description = nil
      @blog.should be_valid
    end
    
    it "should succeed without an email address" do
      @blog.email = nil
      @blog.should be_valid
    end
    
    it "should succeed without a primary URL" do
      @blog.primary_url = nil
      @blog.should be_valid
    end
  end

end