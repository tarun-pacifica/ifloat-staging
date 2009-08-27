require File.join( File.dirname(__FILE__), '..', "spec_helper" )

# detailed (blackbox) find testing is done in the CachedFind spec
# this is OK because this class should be considered essentially private to CachedFind
describe TextFilter do
  
  before(:all) do
    @text_type  = PropertyType.create(:core_type => "text", :name => "text")
    @products = Array.new(5) { DefinitiveProduct.create(:company_id => 1, :reference => "AF11235") }
    @properties = Array.new(5) do |i|
      name = "abc:" + "abc" * (i + 1)
      property = @text_type.definitions.create(:filterable => true, :findable => true,
                                               :name => name, :sequence_number => i)
      @products.each do |product|
        TextPropertyValue.create(:product_id => product.id, :property_definition_id => property.id,
                                 :language_code => "ENG", :text_value => "test")
      end
      property
    end
  end
  
  after(:all) do
    @text_type.destroy
    @products.each { |product| product.destroy }
    @properties.each do |property|
      property.values.destroy!
      property.destroy
    end
  end

  describe "creation" do   
    before(:each) do
      @filter = TextFilter.new(:cached_find_id => 1, :property_definition_id => 1, :language_code => "FRA")
    end
    
    it "should succeed with valid data" do
      @filter.should be_valid
      @filter.text?.should == true
      @filter.fresh?.should == true
    end
    
    it "should fail without a cached find" do
      @filter.cached_find = nil
      @filter.should_not be_valid
    end
    
    it "should fail without a property definition" do
      @filter.property_definition = nil
      @filter.should_not be_valid
    end
    
    it "should fail without a language code" do
      @filter.language_code = nil
      @filter.should_not be_valid
    end
    
    it "should fail with an invalid language code" do
      @filter.language_code = "French"
      @filter.should_not be_valid
    end
  end
  
  describe "value retrieval by filter ID for a given CachedFind" do
    it "should return a hash of values by filter ID for a CachedFind that includes some products" do
      find = CachedFind.create(:language_code => "ENG", :specification => "test")
      find.execute!
      begin
        values_by_id = TextFilter.values_by_filter_id(find)
        values_by_id.size.should == 5
        TextFilter.get(values_by_id.keys.first).cached_find.should == find
        values_by_id.values.first.should == [["test", true]]
      ensure
        find.destroy
      end
    end
    
    it "should return an empty hash for a CachedFind that includes no products" do
      find = CachedFind.create(:language_code => "ENG", :specification => "zest")
      find.execute!
      begin
        TextFilter.values_by_filter_id(find).empty?.should == true
      ensure
        find.destroy
      end
    end
  end
  
  describe "value member checking" do
    it "should return true/false for an known/unkown value" do
      find = CachedFind.create(:language_code => "ENG", :specification => "test")
      find.execute!
      filter = find.filters.first
      begin
        filter.valid_exclusion?("test").should == true
        filter.valid_exclusion?("zest").should == false
      ensure
        find.destroy
      end
    end
  end
  
  it "should have specs for including / excluding values and determoning whether the filter is fresh"

end
