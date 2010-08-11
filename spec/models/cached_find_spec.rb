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
      @find.specification = "   spaced  \t\t\n out  out   terms spaced  "
      @find.should be_valid
      @find.specification.should == "spaced out terms"
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
  
  it "needs specs for filter_values & filter_values_relevant"
  it "needs updated specs for filtered_product_ids (that take the class_only path into account)"
  it "needs specs for language_code"
  
  describe "execution" do
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
      
      Indexer.stub(:compile_image_checksum_index).and_return do
        # TODO: remove once MS hack is removed from indexer
        query =<<-SQL
          SELECT p.id, a.checksum
          FROM products p
            INNER JOIN attachments at ON p.id = at.product_id
            INNER JOIN assets a ON at.asset_id = a.id
          WHERE at.role = 'image'
          ORDER BY at.sequence_number
        SQL

        index = {}
        repository.adapter.select(query).each do |record|
          index[record.id] ||= record.checksum
        end
        index
      end
      
      Indexer.stub(:compile_numeric_filtering_index).and_return do
        # TODO: remove once MS hack is removed from indexer
        query =<<-SQL
          SELECT pv.product_id, pv.property_definition_id, pv.unit, pv.min_value, pv.max_value
          FROM property_values pv
            INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
          WHERE pd.filterable = ?
            AND (pv.min_value IS NOT NULL OR pv.max_value IS NOT NULL)
        SQL

        records = repository.adapter.select(query, true)
        Indexer.compile_filtering_index(records, :unit, :min_value, :max_value)
      end
      
      Indexer.stub(:text_records).and_return do
        # TODO: remove once MS hack is removed from indexer
        query =<<-SQL
          SELECT pd.findable, pd.filterable, pv.product_id, pv.property_definition_id, pv.language_code, pv.text_value
          FROM property_values pv
            INNER JOIN products p ON pv.product_id = p.id
            INNER JOIN property_definitions pd ON pv.property_definition_id = pd.id
          WHERE pv.text_value IS NOT NULL
        SQL
        repository.adapter.select(query)
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
    
    describe "filtering on 'Red' [ENG]" do
      before(:all) { @find = CachedFind.create(:language_code => "ENG", :specification => "Red") }
      
      after(:all) { @find.destroy }
      
      after(:each) { @find.unfilter_all! }
      
      it "should return nil for an unknown property ID" do
        @find.filter!(-1, "value" => "DeadMeat").should == nil
      end
      
      it "should return nil for a property ID outside those imlpied by the specification" do
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
    
    # describe "re-execution on \"Red\" [ENG]" do
    #   before(:each) do
    #     @find = CachedFind.create(:language_code => "FRA", :specification => "Red")
    #     @find.execute!
    #   end
    #   
    #   after(:each) do
    #     @find.destroy
    #   end
    #   
    #   it "should return the same number of products" do
    #     count = @find.products.size
    #     @find.execute!
    #     @find.products.size.should == count
    #   end
    #   
    #   it "should honour existing text filters only if they are in the correct language" do
    #     filter_for_property(:brand).exclude!("DuraBrick")
    #     filter_for_property(:model).exclude!("Taurus")
    #     
    #     model_values = TextPropertyValue.all(:property_definition_id => @properties[:model].id)
    #     model_values.update!(:language_code => "FRA")
    #     
    #     @find.execute!
    #     filter_for_property(:brand).exclusions.empty?.should be_false
    #     filter_for_property(:model).exclusions.empty?.should be_true
    # 
    #     model_values.update!(:language_code => "ENG")
    #   end
    #   
    #   it "should honour exising numeric filter's values only if their chosen units are still valid" do
    #     filter_for_property(:weight_dry).choose!(1.5, 1.6, "kg")
    #     filter_for_property(:weight_wet).choose!(1.4, 1.5, "kg")
    #     
    #     weight_wet_values = NumericPropertyValue.all(:property_definition_id => @properties[:weight_wet].id)
    #     weight_wet_values.update!(:unit => "lb")
    #     
    #     @find.execute!
    #     filter_for_property(:weight_dry).chosen.first.should == 1.5
    #     filter_for_property(:weight_wet).chosen.first.should_not == 1.4
    #     
    #     weight_wet_values.update!(:unit => "kg")
    #   end
    # end
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
