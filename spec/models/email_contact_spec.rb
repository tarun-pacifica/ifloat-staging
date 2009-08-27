require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe EmailContact do

  describe "creation" do   
    before(:each) do
      @contact = EmailContact.new(:user_id => 1, :value => "fish@example.org")
    end
    
    it "should succeed with valid data" do
      @contact.should be_valid
    end
    
    it "should fail without a user" do
      @contact.user = nil
      @contact.should_not be_valid
    end
    
    it "should fail with a variant" do
      @contact.variant = "hotmail"
      @contact.should_not be_valid
    end
    
    it "should fail without a value" do
      @contact.value = nil
      @contact.should_not be_valid
    end
    
    it "should fail with an invalid value" do
      @contact.value = "12345%12387.com"
      @contact.should_not be_valid
    end
    
    it "should convert its value to lowercase" do
      @contact.value = "ANDRE@EXAMPLE.org"
      @contact.valid?
      @contact.value.should == "andre@example.org"
    end
  end

end