require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe TextPropertyValue do

  before(:all) do
    @text = PropertyType.create(:core_type => "text", :name => "text")
  end
  
  after(:all) do
    @text.destroy
  end
  
  def mock_text_value(value)
    t = TextPropertyValue.new(:product_id => 1, :property_definition_id => 1, :value => value, :language_code => "ENG")
    t.stub!(:property_type).and_return(@text) # is this still needed?
    t
  end
  
  describe "creation" do
    before(:each) do
      @value = mock_text_value("red")
    end
    
    it "should succeed with valid data" do
      @value.should be_valid
    end
    
    it "should fail without a product" do
      @value.product = nil
      @value.should_not be_valid
    end
    
    it "should fail without a property definition" do
      @value.definition = nil
      @value.should_not be_valid
    end
    
    it "should fail without a value" do
      proc { @value.value = nil }.should raise_error
    end
    
    it "should fail with a value containing invalid characters" do
      proc { @value.value = "André" }.should raise_error
    end
    
    it "should fail without a language code" do
      @value.language_code = nil
      @value.should_not be_valid
    end
    
    it "should fail with an invalid language code" do
      @value.language_code = "English"
      @value.should_not be_valid
    end
  end
  
  describe "creation with existing value (of the same language code) for a given property definition and product" do    
    before(:all) do
      @value = mock_text_value("red")
      @value.save
    end
    
    after(:all) do
      @value.destroy
    end
    
    it "should succeed with a different value" do
      mock_text_value("green").should be_valid
    end
    
    it "should fail with the same value" do
      mock_text_value("red").should_not be_valid
    end
  end
  
  describe "finding product IDs matching a given spec" do
    before(:all) do
      @properties = {
        "brand"   => @text.definitions.create(:name => "marketing:brand", :findable => true, :sequence_number => 1),
        "colour"  => @text.definitions.create(:name => "appearance:colour", :findable => true, :sequence_number => 2),
        "pattern" => @text.definitions.create(:name => "appearance:pattern", :findable => true, :sequence_number => 3)
      }

      @products = [
        {"brand" => ["Ford",  "ENG"], "colour" => ["Red", "ENG"]},
        {"brand" => ["Ford",  "ENG"], "colour" => ["White", "ENG"]},
        {"brand" => ["Audi",  "ENG"], "colour" => ["Red", "ENG"], "pattern" => ["Forded", "ENG"]},
        {"brand" => ["Clio",  "FRA"], "colour" => ["Rouge", "FRA"]},
        {"brand" => ["Rouge", "ENG"], "colour" => ["Puce", "ENG"]}
      ].each_with_index.map do |info, i|
        product = Product.create(:company_id => i, :reference => "AF11235")
        info.each do |key, info|
          TextPropertyValue.create(:product => product, :definition => @properties[key],
                                   :value => info[0], :language_code => info[1])
        end
        product
      end
    end
    
    after(:all) do
      @properties.each { |key, property| property.destroy }
      @products.each do |product|
        product.values.destroy!
        product.destroy
      end
    end
    
    [ ["Ford",           ["ENG"],        3],
      ["FORD",           ["ENG"],        3],
      ["Forded",         ["ENG"],        1],
      ["Red",            ["ENG"],        2],
      ["Audi",           ["ENG"],        1],
      ["Clio",           ["FRA"],        1],
      ["Clio",           ["DEU"],        0],
      ["Rouge",          ["ENG", "FRA"], 2],
      ["Audi Ford",      ["ENG"],        1]
    ].each do |spec, languages, expected_count|
      it "should return #{expected_count} IDs for #{spec.inspect} #{languages.inspect}" do
        TextPropertyValue.product_ids_matching_spec(spec, languages).size.should == expected_count
      end
    end
  end
end