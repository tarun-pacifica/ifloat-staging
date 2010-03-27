require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Brand do
  
  describe "creation" do
    before(:each) do
      @brand = Brand.new(:asset_id => 1, :company_id => 1, :name => "Musto", :primary_url => "www.musto.com")
    end
    
    it "should succeed with valid data" do
      @brand.should be_valid
    end
    
    it "should fail without an asset" do
      @brand.asset = nil
      @brand.should_not be_valid
    end
    
    it "should fail without a company" do
      @brand.company = nil
      @brand.should_not be_valid
    end
    
    it "should fail without a name" do
      @brand.name = nil
      @brand.should_not be_valid
    end
    
    it "should succeed without a primary URL" do
      @brand.primary_url = nil
      @brand.should be_valid
    end
  end
  
  describe "destruction" do
    it "should destroy any attached image" do
      asset = Asset.create(:company_id => 1, :bucket => "brand_logos", :name => "fishy.jpg")
      brand = Brand.create(:asset_id => 1, :company_id => 1, :name => "Musto", :asset => asset)
      brand.destroy
      Asset.get(asset.id).should == nil
    end
  end
  
end