require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Product do

  describe "creation" do
    before(:each) do
      @product = Product.new(:company_id => 1, :reference => "AF11235", :reference_group => "AF12")
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
    
    it "should fail without a reference group" do
      @product.reference_group = nil
      @product.should be_valid
    end
    
    it "should fail with an invalid reference group" do
      @product.reference_group = " abc "
      @product.should_not be_valid
    end
  end
  
  # TODO: verify all these methods are used
  it "should have specs for marshal_values (instance and class)"
  it "should have specs for prices_by_url_by_product_id"
  it "should have specs for prices_by_url"
  it "should have specs for primary_images_by_product_id"
  it "should have specs for values_by_property_name_by_product_id"
  it "should have specs for values_by_property_name"
  it "should have specs for assets_by_role"
  
end
