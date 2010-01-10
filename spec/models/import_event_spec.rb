require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe ImportEvent do

  describe "creation" do   
    before(:each) do
      @event = ImportEvent.new(:succeeded => true, :report => "All went well.")
    end
    
    it "should succeed with valid data" do
      @event.should be_valid
    end
    
    it "should fail without a success status" do
      @event.succeeded = nil
      @event.should_not be_valid
    end
    
    it "should fail without a report" do
      @event.report = nil
      @event.should_not be_valid
    end
  end

end