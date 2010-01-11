require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe DatePropertyValue do 
  
  describe "creation" do
    before(:all) do
      @date = PropertyType.new(:core_type => "date", :name => "date")
    end
    
    before(:each) do
      @value = DatePropertyValue.new(:product_id => 1,
                                     :property_definition_id => 1,
                                     :min_value => 20090112,
                                     :max_value => 20090112,
                                     :auto_generated => false,
                                     :sequence_number => 1)
    end
    
    it "should succeed with valid data" do
      @value.should be_valid
      @value.range?.should be_false
      @value.value.should == 20090112
    end
    
    it "should succeed with valid data, acting as a range" do
      @value.max_value = 20090113
      @value.should be_valid
      @value.range?.should be_true
      @value.value.should == (20090112..20090113)
    end
    
    it "should fail without a product" do
      @value.product = nil
      @value.should_not be_valid
    end
    
    it "should fail without a property definition" do
      @value.definition = nil
      @value.should_not be_valid
    end
    
    it "should fail without a minimum value" do
      @value.min_value = nil
      @value.should_not be_valid
    end
    
    it "should fail without a maximum value" do
      @value.min_value = nil
      @value.should_not be_valid
    end
    
    it "should fail without an auto-generated indication" do
      @value.auto_generated = nil
      @value.should_not be_valid
    end
    
    it "should fail without a sequence number" do
      @value.sequence_number = nil
      @value.should_not be_valid
    end
    
    it "should fail with a unit" do
      @value.unit = "YYYYMMDD"
      @value.should_not be_valid
    end
    
    it "should fail with a tolerance" do
      @value.tolerance = 1.5
      @value.should_not be_valid
    end
  end
  
  describe "parsing" do
    it "should succeed with a complete date" do
      DatePropertyValue.parse_or_error("20100101").should == {:min_value => 20100101, :max_value => 20100101}
    end
    
    it "should succeed with an indeterminate number of days" do
      DatePropertyValue.parse_or_error("20090100").should == {:min_value => 20090100, :max_value => 20090100}
    end
    
    it "should succeed with an indeterminate number of months and days" do
      DatePropertyValue.parse_or_error("20090000").should == {:min_value => 20090000, :max_value => 20090000}
    end
    
    it "should fail with an indeterminate number of months but a determinate number of days" do
      proc { DatePropertyValue.parse_or_error("20090012") }.should raise_error
    end
    
    it "should succeed with a range" do
      DatePropertyValue.parse_or_error("20090000...20100101").should == {:min_value => 20090000, :max_value => 20100101}
    end
    
    it "should fail with an invalid value" do
      proc { DatePropertyValue.parse_or_error("the year of the Cockerel") }.should raise_error
    end
  end
  
  describe "formatting" do
    it "should succeed for YYYY0000" do
      DatePropertyValue.format_value(20090000).should == "2009"
    end
    
    it "should succeed for YYYYMM00" do
      DatePropertyValue.format_value(20090100).should == "2009-01"
    end
    
    it "should succeed for YYYYMMDD" do
      DatePropertyValue.format_value(20090112).should == "2009-01-12"
    end
  end
  
end