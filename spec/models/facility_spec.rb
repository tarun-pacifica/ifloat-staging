require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Facility do
  
  describe "creation" do
    before(:each) do
      @facility = Facility.new(:company_id => 1, :location_id => 1, :name => "HQ", :primary_url => "hq.example.com", :description => "foo", :purchase_ttl => 60)
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
    
    it "should succeed without a description" do
      @facility.description = nil
      @facility.should be_valid
    end
    
    it "should fail without a purchase TTL" do
      @facility.purchase_ttl = nil
      @facility.should_not be_valid
    end
  end
  
  describe "product_mappings" do
    before(:all) do
      @fac_prod = FacilityProduct.create(:facility_id => 1, :reference => "ABCDE", :price => "52.61", :currency => "GBP")
      @mappings = [
        {:company_id => 1, :product_id => 1, :reference => "ABCDE"},
        {:company_id => 1, :product_id => 2, :reference => "ABCDE;k1=v1;k2=v2"},
        {:company_id => 1, :product_id => 3, :reference => "EDCBA"},
        {:company_id => 2, :product_id => 1, :reference => "ABCDE"},
        {:company_id => 2, :product_id => 2, :reference => "ABCDE;k1=v1;k2=v2"},
        {:company_id => 2, :product_id => 3, :reference => "EDCBA"}
      ].map { |params| ProductMapping.create(params) }
    end
    
    after(:all) do
      ([@fac_prod] + @mappings).each { |o| o.destroy! }
    end
    
    it "should return the set of matching mappings only where facility products exist for them " do
      Facility.new(:id => 1, :company_id => 1).product_mappings([1, 2, 3]).should == @mappings[0, 2]
    end
    
    it "should return an empty hash if no product IDs are specified" do
      Facility.new(:id => 1, :company_id => 1).product_mappings([]).should == []
    end
  end
  
  describe "product_ids_for_refs" do
    before(:all) do
      @mappings = [
        {:company_id => 1, :product_id => 1, :reference => "ABCDE"},
        {:company_id => 1, :product_id => 2, :reference => "ABCDE;k1=v1;k2=v2"},
        {:company_id => 1, :product_id => 3, :reference => "EDCBA"},
        {:company_id => 2, :product_id => 4, :reference => "ABCDE"},
        {:company_id => 2, :product_id => 5, :reference => "ABCDE;k1=v1;k2=v2"},
        {:company_id => 2, :product_id => 6, :reference => "EDCBA"}
      ].map { |params| ProductMapping.create(params) }
    end
    
    after(:all) do
      @mappings.each { |m| m.destroy! }
    end
    
    it "should return the set of matching product IDs from the parent company, including variants" do
      Facility.new(:company_id => 1).product_ids_for_refs(["ABCDE"]).should == [1, 2]
    end
    
    it "should retrun an empty array if no references are specfied" do
      Facility.new(:company_id => 1).product_ids_for_refs([]).should == []
    end
  end
  
  describe "product_url" do
    before(:all) { @mapping = ProductMapping.new(:reference => "ABCDE;k1=v1;k2=v2") }
    
    it "should return a well-formed MarineStore product URL" do
      Facility.new(:primary_url => "marinestore.co.uk").product_url(@mapping).to_s.should == "http://marinestore.co.uk/Merchant2/merchant.mvc?Product_Code=ABCDE&Screen=PROD&Store_Code=mrst"
    end
    
    it "should return an empty URL otherwise" do
      Facility.new.product_url(@mapping).to_s.should == ""
    end
  end
  
  describe "product_urls_by_id" do
    before(:all) do
      @mappings = %w(ABCDE;k1=v1;k2=v2 EBCDA).map do |ref|
        ProductMapping.new(:product_id => rand(100), :reference => ref)
      end
    end
    
    after(:each) do
      result = @facility.product_urls_by_id(@mappings)
      @mappings.each { |m| result[m.product_id].should == @facility.product_url(m) }
    end
    
    it "should return the set of MarineStore product URLs, indexed by product ID" do
      @facility = Facility.new(:primary_url => "marinestore.co.uk")
    end
    
    it "should return a set of empty URLs, indexed by product ID, otherwise" do
      @facility = Facility.new
    end
  end
  
  describe "purchase_urls" do
    before(:all) do
      @mappings = %w(ABCDE;k1=v1;k2=v2 EBCDA).map do |ref|
        [ProductMapping.new(:product_id => rand(100), :reference => ref), 1]
      end
    end
    
    it "should return the set of MarineStore purchase URLs" do
      Facility.new(:primary_url => "marinestore.co.uk").purchase_urls(@mappings).map { |u| u.to_s }.should ==  %w(http://marinestore.co.uk/Merchant2/merchant.mvc?Action=ADPR&Product_Attributes%5B0%5D%3Acode=k1&Product_Attributes%5B0%5D%3Avalue=v1&Product_Attributes%5B1%5D%3Acode=k2&Product_Attributes%5B1%5D%3Avalue=v2&Product_Code=ABCDE&Quantity=1&Screen=BASK&Store_Code=mrst http://marinestore.co.uk/Merchant2/merchant.mvc?Action=ADPR&Product_Code=EBCDA&Quantity=1&Screen=BASK&Store_Code=mrst http://marinestore.co.uk/Merchant2/merchant.mvc?Screen=BASK&Store_Code=mrst)
    end
    
    it "should return an empty array otherwise" do
      Facility.new.purchase_urls(@mappings).should == []
    end
  end
  
  describe "query_url" do
    it "should return a well-formed MarineStore URL" do
      Facility.new(:primary_url => "marinestore.co.uk").query_url("me&you" => "foo=bar").to_s.should == "http://marinestore.co.uk/Merchant2/merchant.mvc?me%26you=foo%3Dbar"
    end
    
    it "should return an empty URL otherwise" do
      Facility.new.query_url("foo" => "bar").to_s.should == ""
    end
  end
  
  describe "update_products" do
    before(:all) do
      @text_type = PropertyType.create(:core_type => "text", :name => "text")
      @ref_class = @text_type.definitions.create(:name => "reference:class", :sequence_number => 1)
      @sale_price = @text_type.definitions.create(:name => "sale:price_min", :sequence_number => 2)
      
      @company = Company.create(:name => "Ford", :reference => "GBR-12345")
      @facility = @company.facilities.create(:name => "Estore", :primary_url => "ford.com", :purchase_ttl => 60)
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