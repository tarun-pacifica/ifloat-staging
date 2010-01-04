require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe CachedFindEvent do

  describe "creation" do
    before(:each) do
      @event = CachedFindEvent.new(:specification => "test", :recalled => true, :ip_address => "10.0.0.1")
    end
    
    it "should succeed with valid data" do
      @event.should be_valid
    end
    
    it "should fail without a specification" do
      @event.specification = nil
      @event.should_not be_valid
    end
    
    it "should fail without a recalled status" do
      @event.recalled = nil
      @event.should_not be_valid
    end
    
    it "should fail without an IP address" do
      @event.ip_address = nil
      @event.should_not be_valid
    end
  end
  
  describe "logging" do
    after(:all) do
      CachedFindEvent.all.destroy!
    end
    
    it "should succeed with valid data" do
      CachedFindEvent.log!("test", true, "10.0.0.1").should be_valid
    end
  end

end