require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Facility do

  describe "creation" do
    before(:each) do
      @facility = Facility.new(:company_id => 1, :location_id => 1, :name => "HQ", :primary_url => "hq.example.com")
    end
    
    it "should succeed with valid data" do
      @facility.should be_valid
    end
    
    it "should fail without a company" do
      @facility.company = nil
      @facility.should_not be_valid
    end
    
    it "should succeed without a location" do
      @facility.location = nil
      @facility.should be_valid
    end
    
    it "should fail without a name" do
      @facility.name = nil
      @facility.should_not be_valid
    end
    
    it "should succeed without a primary URL" do
      @facility.primary_url = nil
      @facility.should be_valid
    end
  end
  
  describe "mapping products" do
    before(:all) do
      @companies = [1, 2].map { |n| Company.create(:name => n, :reference => "GBR-#{n}") }
      @products = (1..9).to_a.map { |n| Product.create(:company => @companies[0], :reference => n) }
      @facilities = [1, 2].map { |n| @companies[1].facilities.create(:name => n, :primary_url => n) }
      @fac_products = (1..9).to_a.map { |n| FacilityProduct.create(:facility => @facilities[n % 2], :reference => n) }
      @mappings = (1..9).to_a.map { |n| ProductMapping.create(:company => @companies[1], :reference => n, :product => @products[n - 1]) }
    end
    
    after(:all) do
      (@mappings + @fac_products + @facilities + @products + @companies).flatten.each { |object| object.destroy }
    end
    
    it "should return the facility product for each product ID specified" do
      product_ids = @products.map { |product| product.id }
      @facilities[0].map_products(product_ids).keys.sort.should == product_ids.values_at(1, 3, 5, 7)
    end
  end

  it "should have some specs for the product retrieval process"
  
  it "should have some specs for the product update process"
  
end