require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe CachedFind do

  describe "creation" do
    before(:each) do
      @find = CachedFind.new(:user_id => 1,
                             :language_code => "ENG",
                             :description => "I need help",
                             :specification => "life jacket")
    end
    
    it "should succeed with valid data" do
      @find.should be_valid
      @find.invalidated.should == false
      proc { @find.filters = 1 }.should raise_error
    end
    
    it "should succeed without a user" do
      @find.user = nil
      @find.should be_valid
    end
    
    it "should fail without a language code" do
      @find.language_code = nil
      @find.should_not be_valid
    end
    
    it "should fail with an invalid language code" do
      @find.language_code = "English"
      @find.should_not be_valid
    end
    
    it "should fail without a specification" do
      @find.specification = nil
      @find.should_not be_valid
    end
    
    it "should use its specification as its default description" do
      @find.description = nil
      @find.specification = "purple helmet"
      @find.should be_valid
      @find.description.should == "purple helmet"
    end
    
    it "should rationalise whitespace and repeated terms in its specification" do
      @find.specification = "   spaced  \t\t out  out   terms spaced  "
      @find.should be_valid
      @find.specification.should == "spaced out terms"
    end
    
    it "should honour tag finds precisely" do
      @find.specification = "{   spaced  \t\t out  out   terms spaced  }"
      @find.should be_valid
      @find.specification.should == "{   spaced  \t\t out  out   terms spaced  }"
    end
    
    it "should fail without an invalidated value" do
      @find.invalidated = nil
      @find.should_not be_valid
    end
  end
  
  describe "modification" do
    before(:all) do
      @find = CachedFind.create(:user_id => 1, :language_code => "ENG", :specification => "life jacket")
    end
    
    after(:all) do
      @find.destroy
    end
    
    it "should fail with a different language" do
      @find.language_code = "FRA"
      @find.should_not be_valid
    end
    
    it "should fail with a different specification" do
      @find.specification = "rubber ducky"
      @find.should_not be_valid
    end
  end
  
  describe "execution" do
    it "should have specs covering tag finds like '{running rigging}'"
    
    before(:all) do
      @text_type = PropertyType.create(:core_type => "text", :name => "text")
      @weight_type = PropertyType.create(:core_type => "numeric", :name => "weight", :units => ["kg", "lb"])
      
      @properties = {}
      sequence_number = 0
      { "appearance:colour"   => @text_type,
        "marketing:brand"     => @text_type,
        "marketing:model"     => @text_type,
        "misc:unused"         => @text_type,
        "physical:weight_dry" => @weight_type,
        "physical:weight_wet" => @weight_type }.each do |name, type|
        findable = (type == @text_type)
        filterable = (name.include?("marketing") or name.include?("physical"))
        property = type.definitions.create(:name => name, :findable => findable, :filterable => filterable, :sequence_number => (sequence_number += 1))
        property_key = property.name.split(":").last.to_sym
        @properties[property_key] = property
      end
      
      @asset = Asset.create(:company_id => 1, :bucket => "products", :name => "car___1.jpg", :checksum => "abcdef")
      @products = []
      [ # Ford Taurus in red / black
        { :brand  => {"ENG" => ["Ford"], "FRA" => ["Ford"]},
          :model  => {"ENG" => ["Taurus"]},
          :colour => {"ENG" => ["Red", "Black"], "FRA" => ["Rouge", "Noir"]} },
        # DeadMeat life jacket in red
        { :brand  => {"ENG" => ["DeadMeat"]},
          :colour => {"ENG" => ["Red"]} },
        # 1KG weight in red
        { :brand      => {"ENG" => ["DuraBrick"]},
          :colour     => {"ENG" => ["Red"]},
          :weight_dry => {"kg"  => [1]},
          :weight_wet => {"kg"  => [0.9]} },
        # 2KG weight in red
        { :brand      => {"ENG" => ["DuraBrick"]},
          :colour     => {"ENG" => ["Red"]},
          :weight_dry => {"kg"  => [2]},
          :weight_wet => {"kg"  => [1.8]} }
      ].each_with_index do |info, i|
        product = Product.create(:company_id => i, :reference => "AF11235")
        @products << product
        
        product.attachments.create(:asset => @asset, :role => "image", :sequence_number => 1)
        
        info.each do |key, values_by_language_unit|
          property = @properties[key]
          value_class = property.property_type.value_class
          language_unit_key = (value_class == TextPropertyValue ? :language_code : :unit)
                    
          values_by_language_unit.each do |language_unit, values|
            values.each do |value|
              attributes = value_class.parse_or_error(value.to_s)
              attributes[:product] = product
              attributes[:definition] = property
              attributes[language_unit_key] = language_unit
              attributes[:auto_generated] = false
              attributes[:sequence_number] = 1
              value_class.create(attributes)
            end
          end
        end
      end
      
      Indexer.compile_to_memory
    end
    
    after(:all) do
      ([@text_type, @weight_type, @asset] + @properties.values).each { |object| object.destroy }

      @products.each do |product|
        product.attachments.destroy!
        product.values.destroy!
        product.destroy
      end
    end
    
    [ ["Black Ford", "ENG", 1],
      ["Black Ford", "FRA", 0],
      ["Ford Noir",  "ENG", 0],
      ["Ford Noir",  "FRA", 1],
      ["Red",        "ENG", 4]
    ].each do |spec, language_code, expected_count|
      it "should return #{expected_count} products for '#{spec}' [#{language_code.inspect}]" do
        find = CachedFind.new(:language_code => language_code, :specification => spec)
        find.all_product_ids.count.should == expected_count
      end
    end
    
    describe "ensuring validity" do
      before(:all) { @find = CachedFind.create(:language_code => "ENG", :specification => "Red") }
      
      after(:all) { @find.destroy }
      
      after(:each) do
        @find.invalidated = true
        @find.unfilter_all!
      end
      
      it "should return [] for a validated find" do
        CachedFind.new(:language_code => "ENG", :specification => "Red", :invalidated => false).ensure_valid.should == []
      end
      
      it "should return [] for an invalidated find with no filters" do
        CachedFind.new(:language_code => "ENG", :specification => "Red").ensure_valid.should == []
      end
      
      it "should return [] for an invalidated find with unchanged filters" do
        @find.filter!(@properties[:brand].id, "value" => "DeadMeat")
        @find.ensure_valid.should == []
      end
      
      it "should return a list of changes for all defunct filters" do
        data = {:data => ["DeadMeat"]}
        @find.attribute_set(:filters, -1 => data, @properties[:brand].id => data)
        @find.ensure_valid.should == ["Discarded filter for defunct property -1"]
      end
      
      it "should return a list of changes for all unsanitizable filters" do
        data = {:data => ["DeadMeat"]}
        @find.attribute_set(:filters, @properties[:unused].id => data, @properties[:brand].id => data)
        @find.ensure_valid.should == ["Discarded filter for misc:unused as unable to sanitize data"]
      end
      
      it "should return a list of changes for all updated filters" do
        @find.attribute_set(:filters, @properties[:brand].id => {:data => ["RedMeat"]})
        @find.ensure_valid.should == ["Updated filter values for marketing:brand"]
      end
    end
    
    describe "filter detail" do
      before(:all) { @find = CachedFind.create(:language_code => "ENG", :specification => "Red") }
      
      after(:all) { @find.destroy }
      
      after(:each) { @find.unfilter_all! }
      
      it "should return nil for an unknown property ID" do
        @find.filter_detail(-1).should == nil
      end
      
      it "should return minimal data for an unused property ID" do
        prop_detail = Indexer.property_display_cache[@properties[:unused].id]
        expected = prop_detail.merge(:values_by_unit => {}, :include_unknown => false)
        @find.filter_detail(@properties[:unused].id).should == expected
      end
      
      it "should return filter data for a used property ID" do
        @find.filter!(@properties[:weight_dry].id, "value" => "1.5::2", "unit" => "kg", "include_unknown" => "true")
        prop_detail = Indexer.property_display_cache[@properties[:weight_dry].id]
        vbu = {"kg" => [[1.0, false, true, "1 kg"], [2.0, true, true, "2 kg"]]}
        expected = prop_detail.merge(:values_by_unit => vbu, :include_unknown => true)
        @find.filter_detail(@properties[:weight_dry].id).should == expected
      end
    end
    
    describe "filtering on 'Red' [ENG]" do
      before(:all) { @find = CachedFind.create(:language_code => "ENG", :specification => "Red") }
      
      after(:all) { @find.destroy }
      
      after(:each) { @find.unfilter_all! }
      
      it "should return nil for an unknown property ID" do
        @find.filter!(-1, "value" => "DeadMeat").should == nil
      end
      
      it "should return nil for a property ID outside those implied by the specification" do
        @find.filter!(@properties[:unused].id, "value" => "DeadMeat").should == nil
      end
      
      it "should allow for unfiltering" do
        @find.filter!(@properties[:brand].id, "value" => "DeadMeat")
        @find.filtered_product_ids.size.should == 1
        @find.unfilter!(@properties[:brand].id).should == true
        @find.unfilter!(@properties[:model].id).should == nil
        @find.filtered_product_ids.size.should == @products.size
      end
      
      it "should return only the life jacket for the brand list ['DeadMeat']" do
        @find.filter!(@properties[:brand].id, "value" => "DeadMeat")
        @find.filtered_product_ids.should == [@products[1].id].to_set
        @find.filtered_product_ids(@properties[:brand].id).size.should == @products.size
        @find.filtered_product_ids_by_image_checksum.should == {@asset.checksum => [@products[1].id]}
        
        @find.filters_unused.size.should == 0
        used = @find.filters_used("::")
        used.size.should == 1
        used.first[:summary].should == "DeadMeat"
      end
      
      it "should return all products for the weight_dry range 1-2 kg (include unknown)" do
        @find.filter!(@properties[:weight_dry].id, "value" => "1::2", "unit" => "kg", "include_unknown" => "true")
        @find.filtered_product_ids.size.should == @products.size
        
        @find.filters_unused.size.should == 3
        used = @find.filters_used("::")
        used.size.should == 1
        used.first[:summary].should == "1::2 kg"
      end
      
      it "should return only the products with a weight_dry range 1-2 kg (exclude unknown)" do
        @find.filter!(@properties[:weight_dry].id, "value" => "1::2", "unit" => "kg")
        @find.filtered_product_ids.should == [@products[2].id, @products[3].id].to_set
      end
      
      it "should return all products but the DuraBrick for the weight_dry range 1.5-2 kg (include unknown)" do
        @find.filter!(@properties[:weight_dry].id, "value" => "1.5::2", "unit" => "kg", "include_unknown" => "true")
        @find.filtered_product_ids.size.should == @products.size - 1
      end
      
      it "should return only the 2KG DuraBrick for the weight_dry range 1.5-2 kg (exclude unknown)" do
        @find.filter!(@properties[:weight_dry].id, "value" => "1.5::2", "unit" => "kg")
        @find.filtered_product_ids.should == [@products[3].id].to_set
      end
    end
  end
    
  describe "unused" do
    before(:all) do
      @finds = []
      [(CachedFind::ANONIMIZATION_TIME + 2.minutes).ago, 2.minutes.ago].each do |t|
        @finds << CachedFind.create(:accessed_at => t, :language_code => "ENG", :specification => "test")
        @finds << CachedFind.create(:user_id => 1, :accessed_at => t, :language_code => "ENG", :specification => "test")
      end
    end

    after(:all) do
      @finds.each { |find| find.destroy }
    end
    
    it "should return all non-anonymous finds accessed longer ago than the ANONIMIZATION_TIME" do
      CachedFind.unused.count.should == 1
    end
  end
  
end
