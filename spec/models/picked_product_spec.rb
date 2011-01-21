require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe PickedProduct do

  describe "creation" do   
    before(:each) do
      @pick = PickedProduct.new(:product_id => 1, :user_id => 1, :group => "buy_now", :cached_brand => "Marlow", :cached_class => "Rope", :invalidated => false)
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
    
    it "should fail without an invalidated state" do
      @pick.invalidated = nil
      @pick.should_not be_valid
    end
  end
  
  describe "all_primary_keys" do
    before(:all) do
      @companies = ["Ford", "Opal"].map { |n| Company.create(:name => n, :reference => "GBR-#{n}") }
      @products = @companies.map { |c| c.products.create(:reference => "#{c.reference}-car".upcase) }
      @picks = 10.times.map { |i| PickedProduct.create(:product => @products[i % 2], :group => "compare", :cached_brand => "b", :cached_class => "c", :invalidated => false) }
    end
    
    after(:all) do
      (@picks + @products + @companies).each { |o| o.destroy! }
    end
    
    it "should return the unique combinations of [company ref, product ref] associated with all picked products" do
      PickedProduct.all_primary_keys.should == [["GBR-Ford", "GBR-FORD-CAR"], ["GBR-Opal", "GBR-OPAL-CAR"]]
    end
  end
  
  describe "handle_orphaned" do
    it "should record warning messages for all non-anonymous orphaned products in the users' inboxes"
    it "should record warning messages for all anonymous orphaned products in the sessions' inboxes"
  end
end