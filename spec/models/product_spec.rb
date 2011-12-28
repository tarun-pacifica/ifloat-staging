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
  
  describe "marshalling values" do
    before(:all) do
      @products = 3.times.map { |i| Product.create(:company_id => 1, :reference => "ABC#{i}") }
      
      @property_types_by_name = Hash[ PropertyType::CORE_TYPES.keys.map do |type|
        [type, PropertyType.create(:core_type => type, :name => type)]
      end ]
      
      @properties_by_name = Hash[ @property_types_by_name.map do |name, type|
        [name, type.definitions.create(:name => "#{name}:#{name}", :sequence_number => 1)]
      end ]
      
      @values = []
      snag = {:sequence_number => 1, :auto_generated => false}
      t = snag.merge(:definition => @properties_by_name["text"], :text_value => "a", :language_code => "ENG")
      n = snag.merge(:definition => @properties_by_name["numeric"], :min_value => 0)
      @products.each_with_index do |prod, i|
        @values << TextPropertyValue.create(t.merge(:product => prod))
        @values << NumericPropertyValue.create(n.merge(:product => prod, :max_value => i))
      end
      
      d = snag.merge(:definition => @properties_by_name["date"], :min_value => 20010101, :max_value => 20030000)
      @values << DatePropertyValue.create(d.merge(:product => @products.first))
      
      # TODO: factor out a complete data set for testing across the various specs
      # TODO: mock indexer object on product (self.indexer and indexer)
      #       thence simplify Indexer.compile as should never be called in test env
      #       note that these properties are required to silence warnings from the indexer
      %w(auto:group_diff marketing:brand reference:class sale:price_min).each do |name|
        pt = @property_types_by_name["text"]
        @properties_by_name[name] = PropertyDefinition.create(:property_type_id => pt.id, :name => name, :sequence_number => 1)
      end
      Indexer.compile
    end
    
    after(:all) do
      (@products + @property_types_by_name.values + @properties_by_name.values + @values).each(&:destroy)
    end
    
    describe "with assets_by_role" do
      it "should return an empty hash by default" do
        @products.first.assets_by_role.should == {}
      end
    end
    
    describe "with marshal_values" do
      def flat_marshal(*args)
        Product.marshal_values(*args).map do |set|
          set.map { |info| info[:values] }.flatten
        end
      end
      
      it "should return common and differentiated values" do
        common, diff = flat_marshal(@products.map(&:id), "ENG", ":::")
        common.should == %w(a)
        diff.sort.should == %w(0 0:::1 0:::2 2001-01-01:::2003)
      end
      
      it "should allow for forcing an otherwise common value to be treated as differentiated" do
        common, diff = flat_marshal(@products.map(&:id), "ENG", ":::", "text:text")
        common.should == []
        diff.sort.should == %w(0 0:::1 0:::2 2001-01-01:::2003 a a a)
      end
      
      it "should provide an instance decorator" do
        common, diff = @products.first.marshal_values("ENG", ":::")
        common.map { |info| info[:values] }.flatten.sort.should == %w(0 2001-01-01:::2003 a)
        diff.should == []
      end
    end
    
    describe "with values_by_property_name_by_product_id" do
      it "should return the values for a given set of property names" do
        values = Product.values_by_property_name_by_product_id(@products.map(&:id), "ENG", %w(text:text date:date))
        values.size.should == @products.size
        values[@products.first.id]["date:date"].should == [@values.last]
      end
      
      it "should return the values for a given set of property IDs" do
        values = Product.values_by_property_name_by_product_id(@products.map(&:id), "ENG", [  @properties_by_name["date"].id])
        values.size.should == 1
        values[@products.first.id]["date:date"].should == [@values.last]
      end
      
      it "should provide an instance decorator" do
        @products.first.values_by_property_name("ENG", %w(date:date))["date:date"].should == [@values.last]
      end
    end
  end
  
  # TODO: verify all these methods are used
  it "should have specs for prices_by_url_by_product_id"
  it "should have specs for prices_by_url"
  it "should have specs for primary_images_by_product_id"
  
end
