require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe DefinitiveProduct do

  describe "creation" do
    before(:each) do
      @product = DefinitiveProduct.new(:company_id => 1, :reference => "AF11235")
    end
    
    it "should succeed with valid data (having a default review stage of 0)" do
      @product.should be_valid
      @product.review_stage.should == 0
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
    
    it "should fail without a review stage" do
      @product.review_stage = nil
      @product.should_not be_valid
    end
  end
  
  describe "creation with existing product" do
    before(:all) do
      @product = DefinitiveProduct.create(:company_id => 1, :reference => "AF11235")
    end
    
    after(:all) do
      @product.destroy
    end
    
    it "should succeed with a different reference for the same company" do
      DefinitiveProduct.new(:company_id => 1, :reference => "BF11235").should be_valid
    end
    
    it "should succeed with a different reference for a different company" do
      DefinitiveProduct.new(:company_id => 2, :reference => "BF11235").should be_valid
    end
    
    it "should fail with the same reference for the same company" do
      DefinitiveProduct.new(:company_id => 1, :reference => "AF11235").should_not be_valid
    end
    
    it "should succeed with the same reference for a different company" do
      DefinitiveProduct.new(:company_id => 2, :reference => "BF11235").should be_valid
    end
  end
  
  describe "import nils" do
    it "should be 'nil' by default" do
      DefinitiveProduct.new.import_nils.should == nil
    end
    
    it "should be an array containing what's supplied" do
      product = DefinitiveProduct.new
      info = [:property, "name", "unit", "seq_num"]
      product.add_import_nil(info)
      product.import_nils.should == [info]
    end
  end
  
end