require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe NumericPropertyValue do
  
  describe "creation" do
    before(:each) do
      @value = NumericPropertyValue.new(:product_id => 1,
                                        :property_definition_id => 1,
                                        :min_value => 22.50,
                                        :max_value => 22.50,
                                        :auto_generated => false,
                                        :sequence_number => 1,
                                        :unit => "GBP")
    end
    
    it "should succeed with valid data" do
      @value.should be_valid
      @value.to_s.should == "22.5 GBP"
    end
    
    it "should succeed with valid data, acting as a range" do
      @value.max_value = 23
      @value.should be_valid
      @value.to_s.should == "22.5...23 GBP"
      @value.to_s("-").should == "22.5-23 GBP"
      @value.comparison_key.should == [22.5, 23, "GBP"]
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
    
    it "should succeed without a unit" do
      @value.unit = nil
      @value.should be_valid
      @value.to_s.should == "22.5"
      @value.comparison_key.should == [22.5, 22.5]
    end
  end
  
  describe "conversion" do
    it "should succeed with a valid conversion" do
      original = {:min_value => 10, :max_value => 20, :unit => "in"}
      NumericPropertyValue.convert(original, "mm").should == {:min_value => 254, :max_value => 508, :unit => "mm"}
    end
    
    it "should honour the maximum significant figures of the input value (with a minimum of 3SF)" do
      original = {:min_value => 0.01, :max_value => 0.01, :unit => "in"}
      NumericPropertyValue.convert(original, "mm")[:min_value].should == 0.254
      
      original = {:min_value => 1.01, :max_value => 1.01, :unit => "in"}
      NumericPropertyValue.convert(original, "mm")[:min_value].should == 25.7
      
      original = {:min_value => 0.01, :max_value => 0.0256, :unit => "in"}
      NumericPropertyValue.convert(original, "mm").values_at(:min_value, :max_value).should == [0.254, 0.65]
    end
    
    it "should retain the entire integer part of the result even if this exceeds the SF of the input" do
      original = {:min_value => 9, :max_value => 9, :unit => "y"}
      NumericPropertyValue.convert(original, "mo")[:min_value].should == 108
    end
        
    it "should fail with an invalid conversion" do
      proc { @value.convert("bananas") }.should raise_error
    end
  end
  
  describe "parsing" do
    it "should succeed with a valid String" do
      NumericPropertyValue.parse_or_error("90210").should == {:min_value => 90210, :max_value => 90210}
      
      ["2", "2.2", "+2", "-2", "2.", ".2", " 2 "].each do |v|
        proc { NumericPropertyValue.parse_or_error(v) }.should_not raise_error
      end
    end
    
    it "should fail with an invalid String" do
      ["a", "15a", "2.2a", ""].each do |v|
        proc { NumericPropertyValue.parse_or_error(v) }.should raise_error
      end
    end
    
    it "should fail with a Number" do
      proc { NumericPropertyValue.parse_or_error(90210) }.should raise_error
    end
    
    it "should fail with a String specifying a number outside the VALUE_RANGE" do
      proc { NumericPropertyValue.parse_or_error(NumericPropertyValue::VALUE_RANGE.first - 1) }.should raise_error
      proc { NumericPropertyValue.parse_or_error(NumericPropertyValue::VALUE_RANGE.last + 1) }.should raise_error
    end
    
    it "should succeed with a valid String range" do
      NumericPropertyValue.parse_or_error("90210...90210.1").should == {:min_value => 90210, :max_value => 90210.1}
      
      ["2...3", " 2...3 ", "2...2.3", "-2.2...+2.3", ".2...3."].each do |v|
        proc { NumericPropertyValue.parse_or_error(v) }.should_not raise_error
      end
    end
    
    it "should fail with an invalid String range" do
      ["a...15a", "2.2a...5", "1..2", ""].each do |v|
        proc { NumericPropertyValue.parse_or_error(v) }.should raise_error
      end
    end
    
    it "should fail with a back-to-front String range" do
      proc { NumericPropertyValue.parse_or_error("90210.1..90210") }.should raise_error
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
    
    it "should succeed for a ranged pair with a custom separator and a unit" do
      NumericPropertyValue.format(1.25, 5.0, "-", "kg").should == "1.25-5 kg"
    end
    
    it "should succeed for a ranged pair with a custom separator and a unit (with fractional support)" do
      NumericPropertyValue.format(1.25, 5.0, "-", "in").should == "1 1/4-5 in"
    end    
  end
    
end
