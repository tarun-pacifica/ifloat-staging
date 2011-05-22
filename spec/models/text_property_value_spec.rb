require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe TextPropertyValue do
  describe "creation" do
    before(:each) do
      @value = TextPropertyValue.new(:product_id => 1, :property_definition_id => 1, :sequence_number => 1,
                                     :text_value => "text", :language_code => "ENG", :auto_generated => 1)
    end
    
    it "should succeed with valid data" do
      @value.should be_valid
      @value.comparison_key.should == ["text"]
      @value.to_s.should == "text"
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
    end
    
    it "should fail with a value containing invalid characters" do
      proc { @value.value = "André" }.should raise_error
    end
    
    it "should fail without a language code" do
      @value.language_code = nil
      @value.should_not be_valid
    end
    
    it "should fail with an invalid language code" do
      @value.language_code = "English"
      @value.should_not be_valid
    end
  end
  
  describe "parsing" do
    it "fail and mark invalid characters" do
      proc { TextPropertyValue.parse_or_error("abc]def") }.should raise_error("invalid characters: abc >>> ] <<< def")
    end
  end
end
