require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe ImContact do

  describe "creation" do   
    before(:each) do
      @contact = ImContact.new(:user_id => 1, :variant => "ICQ", :value => "1234567")
    end
    
    it "should succeed with valid data" do
      @contact.should be_valid
    end
    
    it "should fail without a user" do
      @contact.user = nil
      @contact.should_not be_valid
    end
    
    it "should fail without a variant" do
      @contact.variant = nil
      @contact.should_not be_valid
    end
    
    it "should fail with an invalid variant" do
      @contact.variant = "AVAnatter"
      @contact.should_not be_valid
    end
    
    it "should fail without a value" do
      @contact.value = nil
      @contact.should_not be_valid
    end
  end

end