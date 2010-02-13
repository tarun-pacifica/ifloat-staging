require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Product do

  describe "creation" do
    before(:each) do
      @product = Product.new(:company_id => 1, :reference => "AF11235")
    end
    
    it "should fail without a company" do
      @product.company = nil
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
  
  describe "creation with existing product" do
    before(:all) do
      @product = Product.create(:company_id => 1, :reference => "AF11235")
    end
    
    after(:all) do
      @product.destroy
    end
    
    it "should succeed with a different reference for the same company" do
      Product.new(:company_id => 1, :reference => "BF11235").should be_valid
    end
    
    it "should succeed with a different reference for a different company" do
      Product.new(:company_id => 2, :reference => "BF11235").should be_valid
    end
    
    it "should fail with the same reference for the same company" do
      Product.new(:company_id => 1, :reference => "AF11235").should_not be_valid
    end
    
    it "should succeed with the same reference for a different company" do
      Product.new(:company_id => 2, :reference => "BF11235").should be_valid
    end
  end
  
end
