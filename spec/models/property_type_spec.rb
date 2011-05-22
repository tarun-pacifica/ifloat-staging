require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe PropertyType do

  describe "creation" do   
    before(:each) do
      @type = PropertyType.new(:core_type => "numeric", :name => "weight", :units => ["kg", "lb"])
    end
    
    it "should succeed with valid data" do
      @type.should be_valid
    end
    
    it "should fail without a core type" do
      @type.core_type = nil
      @type.should_not be_valid
    end
    
    it "should fail with an invalid core type" do
      @type.core_type = "time"
      @type.should_not be_valid
    end
    
    it "should fail without a name" do
      @type.name = nil
      @type.should_not be_valid
    end
    
    it "should fail with an invalid name" do
      @type.name = "MyLovelyType_32"
      @type.should_not be_valid
    end
    
    it "should succeed without an array for its units" do
      @type.units = nil
      @type.should be_valid
    end
    
    it "should succeed with an empty array for its units" do
      @type.units = []
      @type.should be_valid
    end
    
    it "should fail with repeated units" do
      @type.units = ["kg", "lb", "kg"]
      @type.should_not be_valid
    end
    
    it "should fail with a nil as one of its units" do
      @type.units = ["kg", nil, "lb"]
      @type.should_not be_valid
    end
    
    it "should fail with invalid units" do
      @type.units = ["kg", "sq. kilometers"]
      @type.should_not be_valid
    end
    
    it "should fail with pairs of units with no known conversion" do
      @type.units = ["kg", "mi"]
      @type.should_not be_valid
    end
  end
  
  describe "class inference" do
    it "should yield a sub-class of PropertyValue for each core type" do
      PropertyType::CORE_TYPES.keys.each do |name|
        klass = PropertyType.new(:core_type => name).value_class
        klass.should_not == PropertyValue
        klass.ancestors.include?(PropertyValue).should be_true 
      end
    end
  end
  
  describe "unit" do
    before(:each) do
      @type = PropertyType.new(:core_type => "numeric", :name => "weight", :units => ["kg"])
    end
    
    it "validation should validate a known unit" do
      @type.validate_unit("kg").should == true
    end
    
    it "validation should not validate an unknown unit" do
      @type.validate_unit("lb").should_not == true
    end
    
    it "validation should insist on nil for all but the numeric core type" do
      @type.core_type = "text"
      @type.validate_unit("kg").should_not == true
    end
  end
end