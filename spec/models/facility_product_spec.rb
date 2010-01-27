require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe FacilityProduct do

  describe "creation" do
    before(:each) do
      @product = FacilityProduct.new(:facility_id => 1, :reference => "AF11235", :price => "52.61", :currency => "GBP")
    end
    
    it "should succeed with valid data" do
      @product.should be_valid
    end
    
    it "should fail without a facility" do
      @product.facility = nil
      @product.should_not be_valid
    end
    
    it "should fail without a reference" do
      @product.reference = nil
      @product.should_not be_valid
    end
    
    it "should fail with an invalid reference" do
      @product.reference = " abc "
      @product.should_not be_valid
    end
    
    it "should fail without a price" do
      @product.price = nil
      @product.should_not be_valid
    end
    
    it "should fail without a currency" do
      @product.currency = nil
      @product.should_not be_valid
    end
    
    it "should fail with an invalid currency" do
      @product.currency = "pounds"
      @product.should_not be_valid
    end
  end
    
end