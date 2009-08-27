require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe FacilityProduct do

  describe "creation" do
    before(:each) do
      @product = FacilityProduct.new(:facility_id => 1, :reference => "AF11235")
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
  end
    
end