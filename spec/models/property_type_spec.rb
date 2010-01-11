require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe PropertyType do

  describe "creation" do   
    before(:each) do
      @type = PropertyType.new(:core_type => "numeric", :name => "weight", :valid_units => ["kg", "lb"])
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
    
    it "should fail without an array for its valid units" do
      @type.valid_units = nil
      @type.should_not be_valid
    end
    
    it "should fail with an empty array for its valid units" do
      @type.valid_units = []
      @type.should_not be_valid
    end
    
    it "should fail with repeated valid units" do
      @type.valid_units = ["kg", "lb", "kg"]
      @type.should_not be_valid
    end
    
    it "should succeed with a single nil for its valid units" do
      @type.valid_units = [nil]
      @type.should be_valid
    end
    
    it "should fail with a nil AND other values for its valid units" do
      @type.valid_units = ["kg", nil, "lb"]
      @type.should_not be_valid
    end
    
    it "should fail with invalid units" do
      @type.valid_units = ["kg", "sq. kilometers"]
      @type.should_not be_valid
    end
    
    it "should fail with pairs of valid units with no known conversion" do
      @type.valid_units = ["kg", "mi"]
      @type.should_not be_valid
    end
  end

  describe "creation with existing type" do
    before(:all) do
      @type = PropertyType.create(:core_type => "text", :name => "text")
    end
    
    after(:all) do
      @type.destroy
    end
    
    it "should succeed with the same core type and a different name" do
      PropertyType.new(:core_type => "text", :name => "prose").should be_valid
    end
    
    it "should fail with the same core type and name" do
      PropertyType.new(:core_type => "text", :name => "text").should_not be_valid
    end
    
    it "should fail with a different core type and the same name" do
      PropertyType.new(:core_type => "decimal", :name => "text").should_not be_valid
    end
  end
  
  describe "modification" do
    before(:all) do
      @type = PropertyType.create(:core_type => "text", :name => "text")
    end
    
    after(:all) do
      @type.destroy
    end
    
    it "should fail with a different core type" do
      @type.core_type = "date"
      @type.should_not be_valid
    end
  end
  
  describe "class inference" do
    it "should yield a sub-class of PropertyValue for each core type" do
      PropertyType::CORE_TYPES.keys.each do |name|
        klass = PropertyType.new(:core_type => name).value_class
        klass.should_not == PropertyValue
        # TODO: find out why a simple 'kind_of?' check fails here
        klass.ancestors.include?(PropertyValue).should be_true 
      end
    end
  end
  
  describe "unit" do
    before(:each) do
      @type = PropertyType.new(:core_type => "numeric", :name => "weight", :valid_units => ["kg"])
    end
    
    it "validation should validate a known unit" do
      @type.validate_unit("kg").should be_true
    end
    
    it "validation should not validate an unknown unit" do
      @type.validate_unit("lb").should_not be_true
    end
    
    it "addition of a new unit should succeed, allowing that unit to validate" do
      @type.add_unit("lb")
      @type.should be_valid
      @type.validate_unit("lb").should be_true
    end
    
    it "deletion of a known unit should succeed, preventing that unit from validating" do
      @type.add_unit("lb")
      @type.delete_unit("lb")
      @type.should be_valid
      @type.validate_unit("lb").should_not be_true
    end
    
    it "deletion of an unknown unit should succeed" do
      @type.delete_unit("bushels")
      @type.should be_valid
    end
    
    it "should raise an error if attempting to alter the units for a core type that doesn't use the units mechanism" do
      @type.core_type = "currency"
      @type.valid_units = nil
      proc { @type.add_unit("lb") }.should raise_error
      proc { @type.delete_unit("lb") }.should raise_error
    end
  end
  
  describe "mandatory units" do
    it "should be empty by default" do
      type = PropertyType.new(:core_type => "currency", :name => "amount")
      type.mandatory_units.should == []
    end
    
    it "should equal the valid units" do
      type = PropertyType.new(:core_type => "numeric", :name => "weight", :valid_units => ["kg", "lb"])
      type.mandatory_units.should == ["kg", "lb"]
    end
  end
  
end