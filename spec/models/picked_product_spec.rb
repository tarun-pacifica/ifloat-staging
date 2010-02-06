require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe PickedProduct do

  describe "creation" do   
    before(:each) do
      @pick = PickedProduct.new(:product_id => 1, :user_id => 1, :group => "buy_now", :cached_brand => "Marlow", :cached_class => "Rope", :invalidated => false)
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
    
    it "should fail without a group" do
      @pick.group = nil
      @pick.should_not be_valid
    end
    
    it "should fail with an invalid group" do
      @pick.group = "mums_birthday"
      @pick.should_not be_valid
    end
    
    it "should fail without a cached brand" do
      @pick.cached_brand = nil
      @pick.should_not be_valid
    end
    
    it "should fail without a cached class" do
      @pick.cached_class = nil
      @pick.should_not be_valid
    end
    
    it "should fail without an invalidated state" do
      @pick.invalidated = nil
      @pick.should_not be_valid
    end
  end
  
  it "should have specs for updating the cached values based on an ensure_valid method"
  
end