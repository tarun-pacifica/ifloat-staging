require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Brand do
  
  describe "creation" do
    before(:each) do
      @brand = Brand.new(:asset_id => 1, :company_id => 1, :name => "Musto", :primary_url => "www.musto.com", :description => "A marine company.")
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
    
    it "should succeed without a description" do
      @brand.description = nil
      @brand.should be_valid
    end
  end
  
  describe "destruction" do
    it "should destroy any attached image" do
      asset = Asset.create(:company_id => 1, :bucket => "brand_logos", :name => "fishy.jpg")
      brand = Brand.create(:company_id => 1, :name => "Musto", :asset => asset)
      brand.destroy
      Asset.get(asset.id).should == nil
    end
  end
  
  describe "logos" do
    before(:all) do
      @asset = Asset.create(:company_id => 1, :bucket => "brand_logos", :name => "fishy.jpg")
      @brand = Brand.create(:company_id => 1, :name => "Musto", :asset => @asset)
    end
    
    after(:all) do
      @brand.destroy
    end
    
    it "should return the logos of any known brands" do
      Brand.logos(["Musto", "Sony", "Apple"]).should == [@asset]
    end
  end
  
  describe "product_ids_by_category_node" do
    before(:all) do
      @brand_property_id = 1
      
      base_info = {
        :property_definition_id => @brand_property_id,
        :sequence_number        => 1,
        :auto_generated         => false,
        :language_code          => "ENG"
      }
      
      @product_id_tvs = [1, 4, 7].map do |id|
        TextPropertyValue.create(base_info.merge(:product_id => id,     :text_value => "Musto"))
        TextPropertyValue.create(base_info.merge(:product_id => id + 1, :text_value => "Misto"))
      end.flatten
      
      @category_tree = {
        []                         => ["Fruit", "Vegetables"],
        ["Fruit"]                  => ["Apples", "Bananas"],
        ["Fruit", "Apples"]        => [1, 2, 3],
        ["Fruit", "Bananas"]       => [4, 5],
        ["Vegetables"]             => ["Carrots", "Onions"],
        ["Vegetables", "Carrots"]  => [6, 7, 8],
        ["Vegetables", "Onions"]   => [9, 10]
      }
    end
    
    before(:each) do
      indexer = mock(:indexer)
      indexer.stub!(:brand_property_id).and_return(@brand_property_id)
      indexer.stub!(:category_children_for_node).and_return { |nodes| @category_tree[nodes] }
      
      @brand = Brand.new(:name => "Musto")
      @brand.stub!(:indexer).and_return(indexer)
    end
    
    after(:all) do
      @product_id_tvs.each(&:destroy)
    end
    
    it "should return all product IDs belonging to the brand at the root node" do
      @brand.product_ids_by_category_node([]).should ==
        {["Fruit", "Apples"] => [1], ["Fruit", "Bananas"] => [4], ["Vegetables", "Carrots"] => [7]}
    end
    
    it "should return the product IDs under a given category branch" do
      @brand.product_ids_by_category_node(["Fruit"]).should == {["Fruit", "Apples"] => [1], ["Fruit", "Bananas"] => [4]}
    end
    
    it "should return the product IDs for a given category leaf" do
      @brand.product_ids_by_category_node(["Fruit", "Apples"]).should == {["Fruit", "Apples"] => [1]}
    end
  end
  
end
