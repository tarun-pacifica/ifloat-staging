require File.join( File.dirname(__FILE__), '..', "spec_helper" )

INFINITY = NumericPropertyValue::INFINITY

describe NumericPropertyValue do
  
  before(:all) do
    @type = PropertyType.create(:core_type => "currency", :name => "price")
    @property = @type.definitions.create(:name => "sale:price", :sequence_number => 1)
  end
  
  after(:all) do
    @type.destroy
    @property.destroy
  end
  
  describe "creation without calling 'value='" do
    it "should fail" do
      NumericPropertyValue.new(:product_id => 1, :definition => @property).should_not be_valid
    end
  end

  describe "creation as a scalar value" do
    before(:each) do
      @value = NumericPropertyValue.new(:product_id => 1, :definition => @property, :value => 22.50, :unit => "GBP")
    end
    
    it "should succeed with valid data, acting like a scalar value" do
      @value.should be_valid
      @value.range?.should == false
      @value.value.should == 22.50
    end
    
    it "should fail without a product" do
      @value.product = nil
      @value.should_not be_valid
    end
    
    it "should fail without a property definition" do
      @value.definition = nil
      @value.should_not be_valid
    end
    
    it "should fail without a value" do
      proc { @value.value = nil }.should raise_error
      proc { @value.value = "?" }.should raise_error
    end
    
    it "should fail with an excessive value" do
      proc { @value.value = NumericPropertyValue::VALUE_RANGE.last + 1 }.should raise_error
    end
    
    it "should succeed with valid string values" do
      ["2", "2.2", "+2", "-2", "2.", ".2", " 2 "].each do |v|
        proc { @value.value = v }.should_not raise_error
      end
    end
    
    it "should fail with invalid string values" do
      ["a", "15a", "2.2a", ""].each do |v|
        proc { @value.value = v }.should raise_error
      end
    end
    
    it "should fail without a unit (given that it's parent type doe not include nil as a valid unit)" do
      @value.unit = nil
      @value.should_not be_valid
    end
    
    it "should fail with an invalid unit" do
      @value.unit = "$"
      @value.should_not be_valid
    end
    
    it "should succeed with a tolerance" do
      @value.tolerance = 1.2
      @value.should be_valid
    end
  end
  
  describe "creation as a range" do
    before(:each) do
      @value = NumericPropertyValue.new(:product_id => 1, :definition => @property, :value => -13.8..15.2, :unit => "GBP")
    end
    
    it "should succeed with valid data, acting like a range" do
      @value.should be_valid
      @value.range?.should == true
      @value.value.should == (-13.8..15.2)
    end
    
    it "should fail with a lower bound greater than its upper bound" do
      proc { @value.value = 6..5 }.should raise_error
    end
    
    it "should succeed with an infinite lower bound" do
      proc { @value.value = -INFINITY..15.2 }.should_not raise_error
      @value.value.should == (-INFINITY..15.2)
    end
    
    it "should succeed with an infinite upper bound" do
      proc { @value.value = -13.8..INFINITY }.should_not raise_error
      @value.value.should == (-13.8..INFINITY)
    end
    
    it "should succeed with equal lower and upper bounds, acting like a scalar value" do
      proc { @value.value = -13.8..-13.8 }.should_not raise_error
      @value.range?.should == false
      @value.value.should == -13.8
    end
    
    it "should fail with an excessive (but real) lower bound" do
      proc { @value.value = (NumericPropertyValue::VALUE_RANGE.first - 1)..5 }.should raise_error
    end
    
    it "should fail with an excessive (but real) upper bound" do
      proc { @value.value = 5..(NumericPropertyValue::VALUE_RANGE.last + 1) }.should raise_error
    end
    
    it "should fail with infinite lower and upper bounds" do
      proc { @value.value = -INFINITY..INFINITY }.should raise_error
    end
    
    it "should succeed with valid string values" do
      ["2...3", " 2...3 ", "2...2.3", "-2.2...+2.3", "-2...?", "?...12.8", ".2...3."].each do |v|
        proc { @value.value = v }.should_not raise_error
      end
    end
    
    it "should fail with invalid string values" do
      ["a...15a", "2.2a...?", "1..2", "?...?", ""].each do |v|
        proc { @value.value = v }.should raise_error
      end
    end
  end
  
  describe "conversion" do
    before(:all) do
      @length_type = PropertyType.new(:core_type => "numeric", :name => "length", :valid_units => ["mm", "in"])
    end
    
    before(:each) do  
      @value = NumericPropertyValue.new(:product_id => 1, :property_definition_id => 1, :value => 10..20, :unit => "in")
    end
    
    it "should succeed with a valid conversion" do
      converted = @value.convert("mm")
      converted.stub!(:property_type).and_return(@length_type)
      converted.should be_valid
      converted.property_definition_id.should == 1
      converted.product_id.should == 1
      converted.value.should == (254..508)
      converted.auto_generated.should == true
      converted.tolerance.should == nil
    end
    
    it "should succeed with a valid conversion when it includes a tolerance" do
      @value.tolerance = 0.111
      converted = @value.convert("mm")
      converted.stub!(:property_type).and_return(@length_type)
      converted.should be_valid 
      converted.tolerance.should == 2.82
    end
    
    it "should cope with an infinite lower bound" do
      @value.value = "?...10"
      @value.convert("mm").value.should == (-NumericPropertyValue::INFINITY..254)
    end
    
    it "should cope with an infinite upper bound" do
      @value.value = "10...?"
      @value.convert("mm").value.should == (254..NumericPropertyValue::INFINITY)
    end
    
    it "should honour the maximum significant figures of the input value (with a minimum of 2SF)" do
      @value.value = 0.01
      @value.convert("mm").value.should == 0.25
      @value.value = 1.01
      @value.convert("mm").value.should == 25.7
      @value.value = 0.01..0.0256
      @value.convert("mm").value.should == (0.254..0.65)
    end
    
    it "should retain the entire integer part of the result even if this exceeds the SF of the input" do
      @value.value = 9
      @value.unit = "y"
      @value.convert("m").value.should == 108
    end
        
    it "should fail with an invalid conversion" do
      proc { @value.convert("bananas") }.should raise_error
    end
  end
  
  describe "formatting" do
    it "should succeed for an Integer" do
      NumericPropertyValue.format_value(1).should == "1"
    end
    
    it "should succeed for a Float with a remainder" do
      NumericPropertyValue.format_value(1.1).should == "1.1"
    end
    
    it "should succeed for a Float with no remainder" do
      NumericPropertyValue.format_value(1.0).should == "1"
    end
    
    it "should succeed for a String with a remainder" do
      NumericPropertyValue.format_value("1.1 fish").should == "1.1"
    end
    
    it "should succeed for a String with no remainder" do
      NumericPropertyValue.format_value("1.0 fish").should == "1"
    end
    
    it "should succeed for a scalar pair" do
      NumericPropertyValue.format(5.2, 5.2).should == "5.2"
    end
    
    it "should succeed for a ranged pair with a default separator" do
      NumericPropertyValue.format(1, 5.2).should == "1...5.2"
    end
    
    it "should succeed for a ranged pair with a custom separator" do
      NumericPropertyValue.format(1.6, 5.0, "-").should == "1.6-5"
    end
  end
  
  describe "retrieving limits by unit by property ID" do
    it "should have specs"
  end
  
end