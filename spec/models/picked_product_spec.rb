require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe PickedProduct do

  describe "creation" do   
    before(:each) do
      @pick = PickedProduct.new(:product_id => 1, :user_id => 1, :group => "buy_now", :cached_brand => "Marlow", :cached_class => "Rope", :quantity => 1, :invalidated => false)
    end
    
    it "should succeed with valid data" do
      @pick.should be_valid
      @pick.orphaned_message.should == "Discontinued Marlow Rope removed from your Basket."
      @pick.title_parts.should == ["Marlow", "Rope"]
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
    
    it "should succeed without a quantity" do
      @pick.quantity = nil
      @pick.should be_valid
    end
    
    it "should fail without an invalidated state" do
      @pick.invalidated = nil
      @pick.should_not be_valid
    end
  end
  
  describe "(with sample DB data) invoking" do
    before(:all) do
      @companies = ["Ford", "Opal"].map { |n| Company.create(:name => n, :reference => "GBR-#{n}") }
      @products = @companies.map { |c| c.products.create(:reference => "#{c.reference}-car".upcase) }
      @picks = 10.times.map { |i| PickedProduct.create(:product => @products[i % 2], :group => "compare", :cached_brand => "b", :cached_class => "c", :invalidated => false) }
      @picks.first.update(:user_id => 1)
      @to_destroy = []
    end
    
    after(:all) do
      (@picks + @products + @companies).each { |o| o.destroy! }
    end
    
    after(:each) do
      @to_destroy.each { |o| o.destroy! }
      @to_destroy = []
    end
    
    it "all_primary_keys should return the unique combinations of [comp-ref, prod-ref] from all picked products" do
      PickedProduct.all_primary_keys.should == [["GBR-Ford", "GBR-FORD-CAR"], ["GBR-Opal", "GBR-OPAL-CAR"]]
    end
  end
end
