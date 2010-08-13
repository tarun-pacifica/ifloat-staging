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
  
  describe "mapping products / references" do
    before(:all) do
      @companies = [1, 2].map { |n| Company.create(:name => n, :reference => "GBR-#{n}") }
      @products = (1..9).to_a.map { |n| Product.create(:company => @companies[0], :reference => n) }
      @facilities = [1, 2].map { |n| @companies[1].facilities.create(:name => n, :primary_url => n) }
      @fac_products = (1..9).to_a.map do |n|
        FacilityProduct.create(:facility => @facilities[n % 2], :reference => n, :price => 42.42, :currency => "GBP")
      end
      @mappings = (1..9).to_a.map { |n| ProductMapping.create(:company => @companies[1], :reference => n, :product => @products[n - 1]) }
    end
    
    after(:all) do
      (@mappings + @fac_products + @facilities + @products + @companies).flatten.each { |object| object.destroy }
    end
    
    it "should return the facility product for each product ID specified" do
      product_ids = @products.map { |product| product.id }
      map = @facilities[0].map_products(product_ids)
      map.keys.sort.should == product_ids.values_at(1, 3, 5, 7)
      fac_prods = map.values
      fac_prods.all? { |v| v.class.should == FacilityProduct }
      fac_prods.uniq.size.should == fac_prods.size
    end
    
    it "should return the product IDs for each reference specified" do
      @facilities[0].map_references([1, 2]).keys.sort.should == @products[0..1].map { |product| product.reference }
    end
  end

  describe "updating products" do
    before(:all) do
      @text_type = PropertyType.create(:core_type => "text", :name => "text")
      @ref_class = @text_type.definitions.create(:name => "reference:class", :sequence_number => 1)
      @sale_price = @text_type.definitions.create(:name => "sale:price_min", :sequence_number => 2)
      
      @company = Company.create(:name => "Ford", :reference => "GBR-12345")
      @facility = @company.facilities.create(:name => "Estore", :primary_url => "ford.com")
      @product = @company.products.create(:reference => "UNUSED-P")
      @prod_class = TextPropertyValue.create(:definition => @ref_class, :product => @product, :text_value => "Fish", :language_code => "ENG", :auto_generated => false, :sequence_number => 1)
      @prod_class.should be_valid
      @unused_mapping = @company.product_mappings.create(:reference => "UNUSED-M", :product => @product)
      
      Indexer.stub(:property_display_cache).and_return(@ref_class.id => {:raw_name => @ref_class.name})
    end
    
    after(:all) do
      [@text_type, @ref_class, @sale_price, @company, @facility, @product, @prod_class, @unused_mapping].each { |object| object.destroy }
    end
        
    it "should create new products, warning on umapped / obsolete mappings (and do nothing if there are no diffs)" do
      @facility.update_products("P1" => {:price => "42.42", :title => "T1", :description => "D1", :image_url => ""}).should == [
        ["P1", "updated: title", "from nil", "to \"T1\""],
        ["P1", "updated: image_url", "from nil", "to \"\""],
        ["P1", "updated: description", "from nil", "to \"D1\""],
        ["P1", "unmapped reference", nil, "T1", "D1", ""],
        ["UNUSED-M", "obsolete mapped reference", "classes: Fish"]
      ]
      @facility.products.count.should == 1
      @facility.update_products("P1" => {:price => "42.42", :title => "T1", :description => "D2", :image_url => ""}).should == [
        ["P1", "updated: description", "from \"D1\"", "to \"D2\""],
        ["P1", "unmapped reference", nil, "T1", "D2", ""],
        ["UNUSED-M", "obsolete mapped reference", "classes: Fish"]
      ]
      @facility.products.count.should == 1
    end
  end
  
end