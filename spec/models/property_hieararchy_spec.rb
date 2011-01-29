require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe PropertyHierarchy do

  describe "creation" do
    before(:each) do
      @hierarchy = PropertyHierarchy.new(:class_name => "foo", :sequence_number => 1, :property_names => ["foo:bar"])
    end
    
    it "should succeed with valid data" do
      @hierarchy.should be_valid
    end
    
    it "should fail without a class name" do
      @hierarchy.class_name = nil
      @hierarchy.should_not be_valid
    end
    
    it "should fail without a sequence number" do
      @hierarchy.sequence_number = nil
      @hierarchy.should_not be_valid
    end
    
    it "should fail without property names" do
      @hierarchy.property_names = nil
      @hierarchy.should_not be_valid
    end
    
    it "should fail with invalid property names" do
      @hierarchy.property_names = "foo:bar,boo:far"
      @hierarchy.should_not be_valid
      @hierarchy.property_names = ["a:1"]
      @hierarchy.should_not be_valid
    end
  end

end
