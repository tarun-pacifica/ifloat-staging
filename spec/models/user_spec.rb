require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe User do
  
  before(:all) do
    @user_attribs = {:name => "Michael Jackson", :nickname => "MJ", :login => "mj@example.com", :password => "sekrit", :confirmation => "sekrit", :created_from => "10.0.0.1"}
  end
  
  describe "creation" do
    before(:each) do
      @user = User.new(@user_attribs)
    end
    
    it "should succeed with valid data" do
      @user.should be_valid
      @user.confirm_key.should =~ /^[0-9A-Za-z]{16}$/
      @user.confirmed_at.should == nil
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
    
    it "should fail if confirmation does not match password" do
      @user.confirmation = nil
      @user.should_not be_valid
    end
    
    it "should fail if created_from is nil" do
      @user.created_from = nil
      @user.should_not be_valid
    end
  end
  
  describe "creation with plain password" do
    before(:each) { @user = User.new(@user_attribs) }
    
    after(:each) { @user.destroy }
    
    it "should hash the password and note the plain one in memory" do
      Password.hashed?(@user.password).should be_false
      @user.plain_password.should == nil
      @user.save.should == true
      Password.hashed?(@user.password).should be_true
      @user.plain_password.should == "sekrit"
    end
  end
  
  describe "authentication" do
    before(:all) do
      @user = User.create(@user_attribs)
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
      @user = User.new(@user_attribs)
    end
    
    it "should be the user's nickname if provided" do
      @user.display_name.should == "MJ"
    end
    
    it "should be the user's name if no nickname is provided" do
      @user.nickname = nil
      @user.display_name.should == "Michael Jackson"
    end
  end
  
  describe "expired" do
    before(:all) do
      now = Time.now
      past = User::UNCONFIRMED_EXPIRY_HOURS.hours.ago - 1
      prefix = "a"
      @users = [[now, now], [now, nil], [past, now], [past, nil]].map do |created_at, confirmed_at|
        login = "#{prefix}@example.com"
        prefix.next!
        User.create(@user_attribs.merge(:login => login, :created_at => created_at, :confirmed_at => confirmed_at))
      end
    end
    
    after(:all) do
      @users.each(&:destroy)
    end
    
    it "should pick out users created longer than #{User::UNCONFIRMED_EXPIRY_HOURS} ago and not confirmed" do
      User.expired.should == [@users.last]
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
