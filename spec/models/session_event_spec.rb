require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe SessionEvent do

  describe "creation" do
    before(:each) do
      @event = SessionEvent.new(:session_id => "abcdef", :type => "GET", :value => "/", :ip_address => "10.0.0.1")
    end
    
    it "should succeed with valid data" do
      @event.should be_valid
    end
    
    it "should fail without a session ID" do
      @event.session_id = nil
      @event.should_not be_valid
    end
    
    it "should fail without a type" do
      @event.type = nil
      @event.should_not be_valid
    end
    
    it "should fail with an invalid type" do
      @event.type = "party"
      @event.should_not be_valid
    end
    
    it "should fail without a value" do
      @event.value = nil
      @event.should_not be_valid
    end
    
    it "should fail without an IP address" do
      @event.ip_address = nil
      @event.should_not be_valid
    end
  end

end
