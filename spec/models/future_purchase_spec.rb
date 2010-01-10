require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe FuturePurchase do

  describe "creation" do   
    before(:each) do
      @purchase = FuturePurchase.new(:definitive_product_id => 1, :user_id => 1, :deferred => true)
    end
    
    it "should succeed with valid data" do
      @purchase.should be_valid
    end
    
    it "should fail without a product" do
      @purchase.product = nil
      @purchase.should_not be_valid
    end
    
    it "should succeed without a user" do
      @purchase.user = nil
      @purchase.should be_valid
    end
    
    it "should fail without a deferred status" do
      @purchase.deferred = nil
      @purchase.should_not be_valid
    end
    
  end
  
  it "should have specs that test the uniquness constraint"

end