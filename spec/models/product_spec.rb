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
      
      @property_display_cache = Indexer.compile_property_display_cache(@properties_by_name.values)
    end
    
    before(:each) do
      indexer = mock(:indexer)
      indexer.stub!(:property_display_cache).and_return(@property_display_cache)
      
      Product.stub!(:indexer).and_return(indexer)
      @products.each { |product| product.stub!(:indexer).and_return(indexer) }
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
  
  describe "prices_by_url_by_product_id" do
    before(:all) do
      @companies = %w(Musto Misto).map { |n| Company.create(:name => n, :reference => "ABC-#{n}", :primary_url => n) }
      @facilities = @companies.map do |c|
        c.facilities.create(:name => c.reference, :purchase_ttl => 0, :primary_url => c.primary_url)
      end
      @fac_prods = @facilities.map do |f|
        [1, 2, 3].map { |i| f.products.create(:reference => i, :price => 5.20, :currency => "GBP") }
        [4, 5, 6].map { |i| f.products.create(:reference => i, :price => 4.80, :currency => "USD") }
      end.flatten
      
      musto = @companies.first
      @mappings = [1, 3, 5].map { |i| ProductMapping.create(:company => musto, :product_id => i, :reference => i)}
    end
    
    after(:all) do
      (@companies + @facilities + @fac_prods + @mappings).each(&:destroy)
    end
    
    it "should return the prices for the given product ID in the given currency" do
      Product.prices_by_url_by_product_id([1, 3], "GBP").should == {1 => {"Musto" => 5.2}, 3 => {"Musto" => 5.2}}
    end
    
    it "should work the same way for a specific object instance" do
      Product.new(:id => 1).prices_by_url("GBP").should == {"Musto" => 5.2}
      Product.new(:id => 2).prices_by_url("GBP").should == {}
    end
  end
  
  describe "primary_images_by_product_id" do
    before(:all) do
      @assets = %w(abc def).map do |checksum|
        Asset.create(:company_id => 1, :bucket => "products", :name => "#{checksum}.jpg", :checksum => checksum)
      end
      @image_checksums_for_product_ids = {"abc" => [1], "def" => [2]}
    end
    
    before(:each) do
      indexer = mock(:indexer)
      indexer.stub!(:image_checksums_for_product_ids).and_return(@image_checksums_for_product_ids)
      indexer.should_receive(:image_checksums_for_product_ids).with([1, 2])
      Product.stub!(:indexer).and_return(indexer)
    end
    
    after(:all) do
      @assets.each(&:destroy)
    end
    
    it "should return the primary images for the given product IDs" do
      Product.primary_images_by_product_id([1, 2]).should == {1 => @assets.first, 2 => @assets.last}
    end
  end
  
  describe "ref_class" do
    before(:all) do
      @product = Product.create(:company_id => 1, :reference => "ABC-123")
      @class = TextPropertyValue.create(:product_id => @product.id, :property_definition_id => 1, :text_value => "a", :language_code => "ENG", :sequence_number => 1, :auto_generated => false)
    end
    
    before(:each) do
      indexer = mock(:indexer)
      indexer.stub!(:class_property_id).and_return(1)
      @product.stub!(:indexer).and_return(indexer)
    end
    
    after(:all) do
      [@product, @class].each(&:destroy)
    end
    
    it "should look up the product's reference:class" do
      @product.ref_class.should == "a"
    end
  end
  
  describe "sibling_properties_with_prod_ids_and_values" do
    before(:all) do
      # TODO: need matching conditions for whole logic of method - note join via first query in that method
      @products = 3.times.map { Product.create(:company_id => 1, :reference => "ABC-123")}
      @property = PropertyDefinition.create(:property_type_id => 1, :sequence_number => 1, :name => "auto:diff")
      @values = 4.times.map do |i|
        TextPropertyValue.create(:definition => @property, :sequence_number => i % 2, :auto_generated => false, :product_id => i / 2, :text_value => i.to_s, :language_code => "ENG")
      end
    end
    
    before(:each) do
      indexer = mock(:indexer)
      indexer.stub!(:auto_diff_property_id).and_return(1)
      @product.stub!(:indexer).and_return(indexer)
      
      PropertyHierarchy.stub!(:lead_property_by_seq_num).and_return do |class_name|
        case class_name
        when "boat" then {}
        when "fish" then {1 => {:raw_name => "auto:same"}}
        when "goat" then {2 => {:raw_name => "auto:diff"}}
        end
      end
      
      @product.reference_group = "ABC-123"
    end
    
    after(:all) do
      (@products + [@property] + @values).each(&:destroy)
    end
    
    it "should return an empty list for products not in a reference group" do
      @product.reference_group = nil
      @product.sibling_properties_with_prod_ids_and_values("ENG", "goat").should == []
    end
    
    it "should return an empty list when no property hierarcies match the product's class" do
      @product.sibling_properties_with_prod_ids_and_values("ENG", "boat").should == []
    end
    
    it "should return an empty list when there are no sibling property values" do
      @product.sibling_properties_with_prod_ids_and_values("ENG", "fish").should == []
    end
    
    it "should return a list of sibling property values otherwise" do
      @product.sibling_properties_with_prod_ids_and_values("ENG", "goat").should == [5, 6]
    end
  end
end
