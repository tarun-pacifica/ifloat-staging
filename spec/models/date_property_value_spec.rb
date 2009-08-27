require File.join( File.dirname(__FILE__), '..', "spec_helper" )

# will only spec the functionality subset not tested by the NumericPropertyValue suite
describe DatePropertyValue do 
  
  describe "creation" do
    before(:all) do
      @date = PropertyType.new(:core_type => "date", :name => "date")
    end
    
    before(:each) do
      @value = DatePropertyValue.new(:product_id => 1, :property_definition_id => 1, :value => 20090112)
      @value.stub!(:property_type).and_return(@date)
    end
    
    it "should succeed with valid data" do
      @value.should be_valid
    end
    
    it "should succeed with an indeterminate number of days" do
      proc { @value.value = 20090100 }.should_not raise_error
      @value.value.should == 20090100
    end
    
    it "should succeed with an indeterminate number of months and days" do
      proc { @value.value = 20090000 }.should_not raise_error
      @value.value.should == 20090000
    end
    
    it "should fail with an indeterminate number of months but a determinate number of days" do
      proc { @value.value = 20090012 }.should raise_error
    end
    
    it "should fail with an invalid value" do
      proc { @value.value = "the year of the Cockerel" }.should raise_error
    end
    
    it "should fail with a unit (as dictated by its parent type)" do
      @value.unit = "YYYYMMDD"
      @value.should_not be_valid
    end
    
    it "should fail with a tolerance" do
      @value.tolerance = 1.5
      @value.should_not be_valid
    end
  end
  
end