require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe PhoneContact do

  describe "creation" do   
    before(:each) do
      @contact = PhoneContact.new(:user_id => 1, :variant => "Mobile", :value => "+44 7972 122 516")
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
      @contact.variant = "batphone"
      @contact.should_not be_valid
    end
    
    it "should fail without a value" do
      @contact.value = nil
      @contact.should_not be_valid
    end
    
    it "should fail with an invalid value" do
      @contact.value = "(01253) 112 536"
      @contact.should_not be_valid
    end
  end
  
end