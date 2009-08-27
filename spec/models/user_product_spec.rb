require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe UserProduct do

  describe "creation" do
    before(:each) do
      @product = UserProduct.new(:definitive_product_id => 1, :location_id => 1, :parent_id => 1,
                                 :purchase_id => 1, :user_id => 1, :reference => "AF11235")
    end
    
    it "should succeed with valid data" do
      @product.should be_valid
    end
    
    it "should fail without a definitive product" do
      @product.definitive_product = nil
      @product.should_not be_valid
    end
    
    it "should succeed without a location" do
      @product.location = nil
      @product.should be_valid
    end
    
    it "should succeed without a parent" do
      @product.parent = nil
      @product.should be_valid
    end
    
    it "should succeed without a purchase" do
      @product.purchase = nil
      @product.should be_valid
    end
    
    it "should fail without a user" do
      @product.user = nil
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
  
  describe "placement in a tree" do
    it "should fail if a cycle would be created"
  end
  
end