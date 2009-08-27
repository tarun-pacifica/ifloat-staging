require File.join( File.dirname(__FILE__), '..', "spec_helper" )

# detailed (blackbox) find testing is done in the CachedFind spec
# this is OK because this class should be considered essentially private to CachedFind
describe NumericFilter do
  
  describe "creation without calling 'limits='" do
    before(:each) do
      @filter = NumericFilter.new(:cached_find_id => 1, :property_definition_id => 1)
    end
    
    it "should fail" do
      @filter.should_not be_valid
    end
    
    it "choose should not fail" do
      proc { @filter.choose!(1, 2, "mm") }.should_not raise_error
    end
    
    it "default_unit should return nil" do
      @filter.default_unit.should == nil
    end
    
    it "excluded_product_query_chunk should return an empty array" do
      @filter.excluded_product_query_chunk.should == []
    end
    
    it "suppress? should return true irrespective of argument" do
      @filter.suppress?(:min).should == true
      @filter.suppress?(:max).should == true
    end
    
    it "units should return an empty array" do
      @filter.units.should == []
    end
  end

  describe "creation without nil limit values" do   
    before(:each) do
      unit_limits = {"mm" => [1, 4], "in" => [2, 3]}
      @filter = NumericFilter.new(:cached_find_id => 1, :property_definition_id => 1, :limits => unit_limits)
    end
    
    it "should succeed with valid data" do
      @filter.should be_valid
      
      @filter.text?.should == false
      @filter.suppress?(:min).should == false
      @filter.suppress?(:max).should == false
      
      @filter.units.should == ["in", "mm"]
      @filter.default_unit.should == "in"
      @filter.chosen.should == [2, 3, "in"]
      @filter.fresh?.should == true
    end
    
    it "should fail without a cached find" do
      @filter.cached_find = nil
      @filter.should_not be_valid
    end
    
    it "should fail without a property definition" do
      @filter.property_definition = nil
      @filter.should_not be_valid
    end
    
    it "should fail without limits" do
      proc { @filter.limits = nil }.should raise_error
    end
    
    it "should fail with empty limits" do
      proc { @filter.limits = {} }.should raise_error
    end
    
    it "should fail with a non-string unit" do
      proc { @filter.limits = {5 => [1, 4]} }.should raise_error
    end
    
    it "should succeed with a nil limit unit" do
      proc { @filter.limits = {nil => [1, 4]} }.should_not raise_error
      
      @filter.units.should == [nil]
      @filter.default_unit.should == nil
      @filter.chosen.should == [1, 4, nil]
      @filter.fresh?.should == true
    end
    
    it "should fail with with a non-array limit" do
      proc { @filter.limits = {"mm" => 6} }.should raise_error
    end
    
    it "should fail with with a limit containing a non-numeric value" do
      proc { @filter.limits = {"mm" => [1, "a"]} }.should raise_error
    end
    
    it "should fail with with a badly-sized limit array" do
      proc { @filter.limits = {"mm" => [1]} }.should raise_error
      proc { @filter.limits = {"mm" => [1, 2, 3]} }.should raise_error
    end
  end
  
  describe "creation with nil values" do
    before(:each) do
      @filter = NumericFilter.new(:cached_find_id => 1, :property_definition_id => 1)
    end
    
    it "should succeed with a limit containing a nil minimum" do
      proc { @filter.limits = {"mm" => [nil, 5]} }.should_not raise_error
      @filter.fresh?.should == true
    end
    
    it "should succeed with a limit containing a nil maximum" do
      proc { @filter.limits = {"mm" => [5, nil]} }.should_not raise_error
      @filter.fresh?.should == true
    end
    
    it "should fail with a mixture of nil limits" do
      proc { @filter.limits = {"in" => [5, nil], "ft" => [nil, 5]} }.should raise_error
    end
    
    it "should fail with with any limit containing two nils" do
      proc { @filter.limits = {"mm" => [nil, nil], "in" => [5, 6]} }.should raise_error
    end
  end
  
  describe "value choice without nil values" do
    before(:each) do
      unit_limits = {"mm" => [1, 4], "in" => [2, 3]}
      @filter = NumericFilter.new(:cached_find_id => 1, :property_definition_id => 1, :limits => unit_limits)
    end
    
    it "should do nothing if supplied with an invalid unit" do
      original_chosen = @filter.chosen
      @filter.choose!(1.5, 3.5, "kg")
      @filter.chosen.should == original_chosen
      @filter.fresh?.should == true
    end
    
    it "should work if supplied with a valid unit and values inside the know ranges" do
      @filter.choose!(1.5, 3.5, "mm")
      @filter.chosen.should == [1.5, 3.5, "mm"]
      @filter.fresh?.should == false
    end
    
    it "should work leaving the filter 'fresh' if returned to its default values" do
      @filter.choose!(1.5, 3.5, "mm")
      @filter.choose!(2, 3, "in")
      @filter.fresh?.should == true
    end
    
    it "should cope with swapped min/max values" do
      @filter.choose!(3.5, 1.5, "mm")
      @filter.chosen.should == [1.5, 3.5, "mm"]
      @filter.fresh?.should == false
    end
    
    it "should snap supplied values to the known range for the given unit" do
      @filter.choose!(0.1, 0.2, "mm")
      @filter.chosen.should == [1, 1, "mm"]
      @filter.fresh?.should == false
      @filter.choose!(0.1, 2, "mm")
      @filter.chosen.should == [1, 2, "mm"]
      @filter.fresh?.should == false
      @filter.choose!(3, 5.2, "mm")
      @filter.chosen.should == [3, 4, "mm"]
      @filter.fresh?.should == false
      @filter.choose!(5.1, 5.2, "mm")
      @filter.chosen.should == [4, 4, "mm"]
      @filter.fresh?.should == false
    end
    
    it "should fill in nil values with defaults" do
      @filter.choose!(nil, nil, "mm")
      @filter.chosen.should == [1, 4, "mm"]
      @filter.fresh?.should == false
    end
  end
  
  describe "value choice with nil min/max values" do
    it "should ignore any minimum filter value when initialized with nil defaults" do
      unit_limits = {"mm" => [nil, 4], "in" => [2, 3]}
      filter = NumericFilter.new(:cached_find_id => 1, :property_definition_id => 1, :limits => unit_limits)
      filter.choose!(3, 3.5, "mm")
      filter.chosen.should == [nil, 3.5, "mm"]
      filter.fresh?.should == false
    end
    
    it "should ignore any maximum filter value when initialized with nil defaults" do
      unit_limits = {"mm" => [1, nil], "in" => [2, 3]}
      filter = NumericFilter.new(:cached_find_id => 1, :property_definition_id => 1, :limits => unit_limits)
      filter.choose!(1.5, 2, "mm")
      filter.chosen.should == [1.5, nil, "mm"]
      filter.fresh?.should == false
    end
  end
  
  describe "resetting the limits" do
    # this is implicitly tested by CachedFind's specs
  end
end