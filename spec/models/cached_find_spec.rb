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
    
    it "should fail with an invalid specification" do
      @find.specification = "life ja"
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
  
  it "needs updated specs for execution"
  it "needs specs for filter_values & filter_values_relevant"
  it "needs specs for the filter! command"
  it "needs updated specs for filtered_product_ids (that take the class_only path into account)"
  it "needs specs for language_code"
  
  describe "execution with product data" do
    before(:all) do
      @text_type = PropertyType.create(:core_type => "text", :name => "text")
      @weight_type = PropertyType.create(:core_type => "numeric", :name => "weight", :valid_units => ["kg", "lb"])
      
      @properties = {}
      sequence_number = 0
      { "appearance:colour"   => @text_type,
        "marketing:brand"     => @text_type,
        "marketing:model"     => @text_type,
        "physical:weight_dry" => @weight_type,
        "physical:weight_wet" => @weight_type }.each do |name, type|
        findable = (type == @text_type)
        filterable = (name.contains?("marketing") or name.contains?("physical"))
        property = type.definitions.create(:name => name, :findable => findable, :filterable => filterable, :sequence_number => (sequence_number += 1))
        property_key = property.name.split(":").last.to_sym
        @properties[property_key] = property
      end

      @products = []
      [ # Ford Taurus in red / black
        { :brand  => {"ENG" => ["Ford"]},
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
        product = DefinitiveProduct.create(:company_id => i, :reference => "AF11235")
        @products << product
        
        info.each do |key, values_by_language_unit|
          property = @properties[key]
          value_class = property.property_type.value_class
          language_unit_key = (value_class == TextPropertyValue ? :language_code : :unit)
                    
          values_by_language_unit.each do |language_unit, values|
            values.each do |value|
              value_class.create(:product => product, :definition => property,
                                 :value => value, language_unit_key => language_unit)
            end
          end
        end
      end
    end
    
    after(:all) do
      @text_type.destroy
      @weight_type.destroy
      
      @properties.each { |key, property| property.destroy }
      
      @products.each do |product|
        product.values.destroy!
        product.destroy
      end
    end

    def filter_for_property(key)
      property = @properties[key]
      @find.filters.find { |f| f.property_definition == property }
    end
    
    describe "product_count" do
      it "should only succeed once products has been called" do
        find = CachedFind.create(:language_code => "ENG", :specification => "Red")
        find.execute!
        proc { find.product_count }.should raise_error
        find.products
        proc { find.product_count }.should_not raise_error
        find.destroy
      end
    end
    
    describe "spec_date" do
      before(:each) do
        @find = CachedFind.create(:language_code => "ENG", :specification => "Red")
      end
      
      after(:each) do
        @find.destroy
      end
      
      it "should be 'Red' before execution" do
        @find.spec_date.should == "Red"
      end
      
      it "should be like 'Red (2004/01/12 15:38:26)' after execution" do
        @find.execute!
        @find.spec_date.should == "Red (#{@find.executed_at.strftime('%Y/%m/%d %H:%M:%S')})"
      end
    end
    
    [ ["Black Ford", "ENG", 1],
      ["Black Ford", "FRA", 1],
      ["Ford Noir",  "ENG", 0],
      ["Ford Noir",  "FRA", 1],
      ["Red",        "ENG", 4]
    ].each do |spec, language_code, expected_count|
      it "should return #{expected_count} products for #{spec.inspect} [#{language_code.inspect}]" do
        find = CachedFind.create(:language_code => language_code, :specification => spec)
        find.execute!
        begin
          find.all_product_count.should == expected_count
        ensure
          find.destroy
        end
      end
    end
    
    describe "filtering on \"Red\" [ENG]" do
      before(:all) { @find = CachedFind.create(:language_code => "ENG", :specification => "Red") }
      
      after(:all) { @find.destroy }
      
      before(:each) do
        @find.filters.each { |filter| filter.destroy }
        @find.execute!
      end
    
      it "should return only the life jacket for the brand list [\"DeadMeat\"]" do
        filter = filter_for_property(:brand)
        filter.exclude!("DuraBrick")
        filter.exclude!("Ford")
        @find.products.should == [@products[1]]
      end
      
      it "should return all products for the weight_dry range 1-2 kg" do
        filter = filter_for_property(:weight_dry)
        filter.choose!(1, 2, "kg")
        @find.products.size.should == @products.size
      end
      
      it "should return all products but the DuraBrick for the weight_dry range 1.5-2 kg" do
        filter = filter_for_property(:weight_dry)
        filter.choose!(1.5, 2, "kg")
        @find.products.size.should == @products.size - 1
      end
    end
    
    describe "re-execution on \"Red\" [ENG]" do
      before(:each) do
        @find = CachedFind.create(:language_code => "FRA", :specification => "Red")
        @find.execute!
      end
      
      after(:each) do
        @find.destroy
      end
      
      it "should return the same number of products" do
        count = @find.products.size
        @find.execute!
        @find.products.size.should == count
      end
      
      it "should honour existing text filters only if they are in the correct language" do
        filter_for_property(:brand).exclude!("DuraBrick")
        filter_for_property(:model).exclude!("Taurus")
        
        model_values = TextPropertyValue.all(:property_definition_id => @properties[:model].id)
        model_values.update!(:language_code => "FRA")
        
        @find.execute!
        filter_for_property(:brand).exclusions.empty?.should be_false
        filter_for_property(:model).exclusions.empty?.should be_true

        model_values.update!(:language_code => "ENG")
      end
      
      it "should honour exising numeric filter's values only if their chosen units are still valid" do
        filter_for_property(:weight_dry).choose!(1.5, 1.6, "kg")
        filter_for_property(:weight_wet).choose!(1.4, 1.5, "kg")
        
        weight_wet_values = NumericPropertyValue.all(:property_definition_id => @properties[:weight_wet].id)
        weight_wet_values.update!(:unit => "lb")
        
        @find.execute!
        filter_for_property(:weight_dry).chosen.first.should == 1.5
        filter_for_property(:weight_wet).chosen.first.should_not == 1.4
        
        weight_wet_values.update!(:unit => "kg")
      end
    end
  end if false
  
  describe "execution without product data" do
    it "should fail if the find is not valid" do
      find = CachedFind.new(:language_code => "ENG", :specification => nil)
      proc { find.execute! }.should raise_error
    end
    
    it "should fail if the find is not saved" do
      find = CachedFind.new(:language_code => "ENG", :specification => "Black Ford")
      proc { find.execute! }.should raise_error
    end
    
    it "should succeed if the find is valid" do
      find = CachedFind.create(:language_code => "ENG", :specification => "Black Ford")
      begin
        proc { find.execute! }.should_not raise_error
      ensure
        find.destroy
      end
    end
  end if false
  
  describe "destruction" do
    it "should destroy any child filters (and thence exclusions)" do
      find = CachedFind.create(:language_code => "ENG", :specification => "Red")
      filter = TextFilter.create(:cached_find => find, :property_definition_id => 1, :language_code => "ENG")
      filter.exclude!("DeadMeat")
      find.destroy
      begin
        TextFilter.first(:cached_find_id => find.id).should be_nil
        TextFilterExclusion.first(:filter_id => filter.id).should be_nil
      ensure
        TextFilter.all(:id => filter.id).destroy!
        TextFilterExclusion.all(:filter_id => filter.id).destroy!
      end
    end
  end if false
  
  describe "should be classified as" do
    before(:all) do
      outside_anon = (CachedFind::ANONIMIZATION_TIME + 2.minutes).ago
      outside_ttl = (Merb::Config[:session_ttl] + 2.minutes).ago
      recently = 2.minutes.ago
      
      @finds = []
      [outside_anon, outside_ttl, recently].each do |t|
        @finds << CachedFind.create(:accessed_at => t, :language_code => "ENG", :specification => "test")
        @finds << CachedFind.create(:user_id => 1, :accessed_at => t, :language_code => "ENG", :specification => "test")
      end
    end

    after(:all) do
      @finds.each { |find| find.destroy }
    end
    
    it "obsolete if both anonymous and accessed longer ago than the current session TTL" do
      CachedFind.obsolete.count.should == (CachedFind::ANONIMIZATION_TIME > Merb::Config[:session_ttl] ? 2 : 1)
    end

    it "unused if both owned and accessed longer ago than the ANONIMIZATION_TIME" do
      CachedFind.unused.count.should == (CachedFind::ANONIMIZATION_TIME > Merb::Config[:session_ttl] ? 1 : 2)
    end
  end
  
end
