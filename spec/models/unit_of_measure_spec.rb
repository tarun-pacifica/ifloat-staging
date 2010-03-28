require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe UnitOfMeasure do
  
  describe "creation" do
    before(:each) do
      @uom = UnitOfMeasure.new(:property_definition_id => 1, :class_name => "Paint", :unit => "l")
    end
    
    it "should succeed with valid data" do
      @uom.should be_valid
    end
    
    it "should fail without a property definition" do
      @uom.property_definition = nil
      @uom.should_not be_valid
    end
    
    it "should fail without a class name" do
      @uom.class_name = nil
      @uom.should_not be_valid
    end
    
    it "should fail without a unit" do
      @uom.unit = nil
      @uom.should_not be_valid
    end
  end
  
end