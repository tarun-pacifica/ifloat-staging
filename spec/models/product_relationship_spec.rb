require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe ProductRelationship do
  
  before(:all) do
    @text_type = PropertyType.create(:core_type => "text", :name => "text")
    @numeric_type = PropertyType.create(:core_type => "numeric", :name => "clothing_size")
    
    @text_property = @text_type.definitions.create(:name => "marketing:model", :sequence_number => 1)
    @numeric_property = @numeric_type.definitions.create(:name => "clothing:size", :sequence_number => 2)
  end
  
  after(:all) do
    [@text_type, @numeric_type, @text_property, @numeric_property].each do |entity|
      entity.destroy
    end
  end

  describe "creation" do
    before(:each) do
      @relationship = ProductRelationship.new(:company_id => 1,
                                              :product_id => 1,
                                              :property_definition => @text_property,
                                              :name => "is_used_on",
                                              :value => "Astra",
                                              :bidirectional => true)
    end
    
    it "should succeed with valid data" do
      @relationship.should be_valid
    end
    
    it "should succeed without a company" do
      @relationship.company = nil
      @relationship.should be_valid
    end
    
    it "should fail without a product" do
      @relationship.product = nil
      @relationship.should_not be_valid
    end
    
    it "should succeed without a property definition" do
      @relationship.property_definition = nil
      @relationship.should be_valid
    end
    
    it "should fail without a name" do
      @relationship.name = nil
      @relationship.should_not be_valid
    end
    
    it "should fail with an invalid name" do
      @relationship.name = "AUNTIE"
      @relationship.should_not be_valid
    end
    
    it "should fail without a value" do
      @relationship.value = nil
      @relationship.should_not be_valid
    end
    
    it "should fail without a bidirectional indication" do
      @relationship.bidirectional = nil
      @relationship.should_not be_valid
    end
  end
  
  describe "related products within a single company" do
    before(:all) do
      @sparklies = Company.create(:name => "Sparklies", :reference => "GBR-12345")
      
      @products = []
      ["Necklace", "Clasp", "Earring"].each_with_index do |thing, i|
        product = Product.create(:company => @sparklies, :reference => "ABC#{i}")
        TextPropertyValue.create(:product => product, :definition => @text_property, :sequence_number => 1,
                                 :text_value => thing, :language_code => "ENG", :auto_generated => false)
        @products << product
      end
      
      @products[0].product_relationships.create(:name => "goes_well_with", :property_definition => @text_property, :value => "Earring", :bidirectional => true)
      @products[1].product_relationships.create(:name => "is_used_on", :value => "ABC0", :bidirectional => true)
    end
    
    after(:all) do
      @sparklies.destroy
      
      @products.each do |product|
        product.product_relationships.destroy!
        product.values.destroy!
        product.destroy
      end
    end
    
    it "should yield the clasp (used) and the earring (goes well) for the necklace" do
      ProductRelationship.related_products(@products[0]).should == {
        "uses" => [ @products[1] ],
        "goes_well_with" => [ @products[2] ]
      }
    end
    
    it "should yield the necklace (used) for the clasp" do
      ProductRelationship.related_products(@products[1]).should == {
        "is_used_on" => [ @products[0] ]
      }
    end
    
    it "should yield the necklace (goes well) for the earring" do
      ProductRelationship.related_products(@products[2]).should == {
        "goes_well_with" => [ @products[0] ]
      }
    end
    
    it "should be completely described by compile_index" do
      p1, p2, p3 = @products.map(&:id)
      ProductRelationship.compile_index.should == {
        p1 => {"goes_well_with" => [p3], "uses" => [p2]},
        p2 => {"is_used_on" => [p1]},
        p3 => {"goes_well_with" => [p1]}
      }
    end
    
    it "should have specs that test uni-directional relationships"
  end
  
  describe "related products across multiple companies" do
    before(:all) do
      @sparklies = Company.create(:name => "Sparklies", :reference => "GBR-12345")
      @tinselies = Company.create(:name => "Tinselies", :reference => "GBR-54321")
      
      @products = []
      ["Necklace", "Clasp", "Earring"].each_with_index do |thing, i|
        product = Product.create(:company => @sparklies, :reference => "ABC#{i}")
        TextPropertyValue.create(:product => product, :definition => @text_property, :sequence_number => 1,
                                 :text_value => thing, :language_code => "ENG", :auto_generated => false)
        @products << product
      end
      
      ["Clasp", "Earring"].each_with_index do |thing, i|
        product = Product.create(:company => @tinselies, :reference => "CBA#{i}")
        TextPropertyValue.create(:product => product, :definition => @text_property, :sequence_number => 1,
                                 :text_value => thing, :language_code => "ENG", :auto_generated => false)
        @products << product
      end
      
      @products[0].product_relationships.create(:name => "goes_well_with", :value => "Earring",
                                                :company => @sparklies, :property_definition => @text_property,
                                                :bidirectional => true)
      @products[1].product_relationships.create(:name => "is_used_on", :value => "ABC0", :company => @sparklies,
                                                :bidirectional => true)
      @products[2].product_relationships.create(:name => "is_used_on", :value => "ABC0", :company => @tinselies,
                                                :bidirectional => true)
    end
    
    after(:all) do
      @sparklies.destroy
      @tinselies.destroy
      
      @products.each do |product|
        product.product_relationships.destroy!
        product.values.destroy!
        product.destroy
      end
    end
    
    it "should yield the the Sparklies clasp (used) and the Sparklies Earring for the Sparklies necklace" do
      ProductRelationship.related_products(@products[0]).should == {
        "uses" => [ @products[1] ],
        "goes_well_with" => [ @products[2] ]
      }
    end
    
    it "should yield the Sparklies necklace (used) for the Sparklies clasp" do
      ProductRelationship.related_products(@products[1]).should == { "is_used_on" => [ @products[0] ] }
    end
    
    it "should yield the Sparklies necklace (goes well) for the Sparklies Earring" do
      ProductRelationship.related_products(@products[2]).should == { "goes_well_with" => [ @products[0] ] }
    end

    it "should yield no related products for the Tinselies clasp" do
      ProductRelationship.related_products(@products[3]).should == {}
    end
    
    it "should yield no related products for the Tinselies earring" do
      ProductRelationship.related_products(@products[4]).should == {}
    end
    
    it "should have specs that test uni-directional relationships"
  end
  
end