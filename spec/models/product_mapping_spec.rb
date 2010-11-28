require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe ProductMapping do

  describe "creation" do
    before(:each) do
      @mapping = ProductMapping.new(:company_id => 1, :product_id => 1, :reference => "BB09876")
    end
    
    it "should succeed with valid data" do
      @mapping.should be_valid
      @mapping.reference_parts.should == ["BB09876", []]
    end
    
    it "should fail without a company" do
      @mapping.company = nil
      @mapping.should_not be_valid
    end
    
    it "should fail without a product" do
      @mapping.product = nil
      @mapping.should_not be_valid
    end
    
    it "should fail without a reference" do
      @mapping.reference = nil
      @mapping.should_not be_valid
    end
    
    it "should fail with an invalid reference" do
      @mapping.reference = " abc "
      @mapping.should_not be_valid
    end
    
    it "should succeed with a varied reference" do
      @mapping.reference = "BB09876;foo=42;bar=12"
      @mapping.should be_valid
      @mapping.reference_parts.should == ["BB09876", [["foo", "42"], ["bar", "12"]]]
    end
  end

end
