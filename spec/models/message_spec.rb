require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Message do

  describe "creation" do   
    before(:each) do
      @message = Message.new(:user_id => 1, :value => "Hello world.")
    end
    
    it "should succeed with valid data" do
      @message.should be_valid
    end
    
    it "should fail without a user" do
      @message.user = nil
      @message.should_not be_valid
    end
    
    it "should fail without a value" do
      @message.value = nil
      @message.should_not be_valid
    end
  end

end