require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe User do

  describe "creation" do   
    before(:each) do
      @user = User.new(:name => "Michael Jackson", :nickname => "MJ", :login => "mj@example.com", :password => "sekrit")
    end
    
    it "should succeed with valid data" do
      @user.should be_valid
    end
    
    it "should fail without a name" do
      @user.name = nil
      @user.should_not be_valid
    end
    
    it "should succeed without a nickname" do
      @user.nickname = nil
      @user.should be_valid
    end
    
    it "should fail without a login" do
      @user.login = nil
      @user.should_not be_valid
    end
    
    it "should fail with an invalid login" do
      @user.login = "mj99"
      @user.should_not be_valid
    end
    
    it "should convert its entire login to lowercase" do
      @user.login = "MJ@EXAMPLE.COM"
      @user.should be_valid
      @user.login.should == "mj@example.com"
    end
    
    it "should fail without a password" do
      @user.password = nil
      @user.should_not be_valid
    end
  end
  
  describe "creation with existing user" do
    before(:all) do
      @user = User.create(:name => "Michael Jackson", :login => "mj@example.com", :password => "sekrit")
    end
    
    after(:all) do
      @user.destroy
    end
    
    it "should succeed with a different login" do
      User.new(:name => "Michael Jordan", :login => "mijo@example.com", :password => "sekrit").should be_valid
    end
    
    it "should fail with the same login" do
      User.new(:name => "Michael Jordan", :login => "mj@example.com", :password => "sekrit").should_not be_valid
    end
  end
  
  describe "authentication" do
    before(:all) do
      @user = User.create(:name => "Michael Jackson", :login => "mj@example.com", :password => Password.hash("sekrit"))
    end
    
    after(:all) do
      @user.destroy
    end
    
    it "should succeed with a valid login and password" do
      User.authenticate("mj@example.com", "sekrit").class.should == User
    end
    
    it "should fail with a valid login and invalid password" do
      User.authenticate("mj@example.com", "SEKRIT").should be_nil
    end
    
    it "should fail with an invalid login and valid password" do
      User.authenticate("oj@example.com", "sekrit").should be_nil
    end
    
    it "should fail with an invalid login and password" do
      User.authenticate("oj@example.com", "SEKRIT").should be_nil
    end
  end

  describe "display name" do
    before(:each) do
      @user = User.new(:name => "Michael Jackson", :nickname => "MJ", :login => "mj@example.com", :password => "sekrit")
    end
    
    it "should be the user's nickname if provided" do
      @user.display_name.should == "MJ"
    end
    
    it "should be the user's name if no nickname is provided" do
      @user.nickname = nil
      @user.display_name.should == "Michael Jackson"
    end
  end
  
  describe "reset password" do
    it "should succeed, issuing a random password which can be accessed in memory" do
      user = User.new(:password => "sekrit")
      user.reset_password
      user.plain_password.blank?.should be_false
      Password.match?(user.password, user.plain_password).should be_true
    end
  end
end