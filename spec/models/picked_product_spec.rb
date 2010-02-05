require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe PickedProduct do

  describe "creation" do   
    before(:each) do
      @pick = PickedProduct.new(:product_id => 1, :user_id => 1, :deferred => true)
    end
    
    it "should succeed with valid data" do
      @pick.should be_valid
    end
    
    it "should fail without a product" do
      @pick.product = nil
      @pick.should_not be_valid
    end
    
    it "should succeed without a user" do
      @pick.user = nil
      @pick.should be_valid
    end
    
    it "should fail without a deferred status" do
      @pick.deferred = nil
      @pick.should_not be_valid
    end
    
  end
  
end