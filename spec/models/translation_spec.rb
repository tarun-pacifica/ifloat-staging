require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Translation do
  describe "creation" do
    before(:each) do
      @translation = Translation.new(:property_definition_id => 1, :language_code => "FRA", :value => "rouge")
    end
    
    it "should succeed with valid data" do
      @translation.should be_valid
    end
    
    it "should fail without a property definition" do
      @translation.property_definition = nil
      @translation.should_not be_valid
    end
    
    it "should fail without a language code" do
      @translation.language_code = nil
      @translation.should_not be_valid
    end
    
    it "should fail with an invalid language code" do
      @translation.language_code = "French"
      @translation.should_not be_valid
    end
    
    it "should fail without a value" do
      @translation.value = nil
      @translation.should_not be_valid
    end
  end
end
