require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Relationship do
  
  before(:all) do
    @text_type = PropertyType.create(:core_type => "text", :name => "text")
    @numeric_type = PropertyType.create(:core_type => "numeric", :name => "clothing_size", :valid_units => [nil])
    
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
      @relationship = Relationship.new(:company_id => 1,
                                       :definitive_product_id => 1,
                                       :property_definition => @text_property,
                                       :name => "used_on",
                                       :value => "Astra")
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
    
    it "should fail with a numeric property definition" do
      @relationship.property_definition = @numeric_property
      @relationship.should_not be_valid
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
  end

  describe "creation with existing relationship for a company, product and property definition" do
    before(:all) do
      @text_property2 = @text_type.definitions.create(:name => "marketing:edition", :sequence_number => 1)
      @relationship = Relationship.create(:company_id => 1,
                                          :definitive_product_id => 1,
                                          :property_definition => @text_property,
                                          :name => "used_on",
                                          :value => "Astra")
    end
    
    after(:all) do
      @text_property2.destroy
      @relationship.destroy
    end
    
    it "should succeed with a different company" do
      Relationship.new(:company_id => 2, :definitive_product_id => 1, :property_definition => @text_property,
                       :name => "used_on", :value => "Astra").should be_valid
    end
    
    it "should succeed with a different product" do
      Relationship.new(:company_id => 1, :definitive_product_id => 2, :property_definition => @text_property,
                       :name => "used_on", :value => "Astra").should be_valid
    end
    
    it "should succeed with a different property definition" do
      Relationship.new(:company_id => 1, :definitive_product_id => 1, :property_definition => @text_property2,
                       :name => "used_on", :value => "Astra").should be_valid
    end
    
    it "should succeed with a different name" do
      Relationship.new(:company_id => 1, :definitive_product_id => 1, :property_definition => @text_property,
                       :name => "works_with", :value => "Astra").should be_valid
    end
    
    it "should succeed with a different value" do
      Relationship.new(:company_id => 1, :definitive_product_id => 1, :property_definition => @text_property,
                       :name => "used_on", :value => "Polo").should be_valid
    end
    
    it "should fail with the same value" do
      Relationship.new(:company_id => 1, :definitive_product_id => 1, :property_definition => @text_property,
                       :name => "used_on", :value => "Astra").should_not be_valid
    end
  end
  
  describe "related products within a single company" do
    before(:all) do
      @sparklies = Company.create(:name => "Sparklies", :reference => "GBR-12345")
      
      @products = []
      ["Necklace", "Clasp", "Earring"].each_with_index do |thing, i|
        product = DefinitiveProduct.create(:company => @sparklies, :reference => "ABC#{i}")
        TextPropertyValue.create(:product => product, :definition => @text_property,
                                 :value => thing, :language_code => "ENG")
        @products << product
      end
      
      @products[0].relationships.create(:name => "goes_well_with", :property_definition => @text_property, :value => "Earring")
      @products[1].relationships.create(:name => "used_on", :value => "ABC0")
    end
    
    after(:all) do
      @sparklies.destroy
      
      @products.each do |product|
        product.relationships.destroy!
        product.values.destroy!
        product.destroy
      end
    end
    
    it "should yield the clasp (used) and the earring (goes well) for the necklace" do
      Relationship.related_products(@products[0]).should == {
        "uses" => [ @products[1] ],
        "goes_well_with" => [ @products[2] ]
      }
    end
    
    it "should yield the necklace (used) for the clasp" do
      Relationship.related_products(@products[1]).should == {
        "used_on" => [ @products[0] ]
      }
    end
    
    it "should yield the necklace (goes well) for the earring" do
      Relationship.related_products(@products[2]).should == {
        "goes_well_with" => [ @products[0] ]
      }
    end
  end
  
  describe "related products across multiple companies" do
    before(:all) do
      @sparklies = Company.create(:name => "Sparklies", :reference => "GBR-12345")
      @tinselies = Company.create(:name => "Tinselies", :reference => "GBR-54321")
      
      @products = []
      ["Necklace", "Clasp", "Earring"].each_with_index do |thing, i|
        product = DefinitiveProduct.create(:company => @sparklies, :reference => "ABC#{i}")
        TextPropertyValue.create(:product => product, :definition => @text_property,
                                 :value => thing, :language_code => "ENG")
        @products << product
      end
      
      ["Clasp", "Earring"].each_with_index do |thing, i|
        product = DefinitiveProduct.create(:company => @tinselies, :reference => "CBA#{i}")
        TextPropertyValue.create(:product => product, :definition => @text_property,
                                 :value => thing, :language_code => "ENG")
        @products << product
      end
      
      @products[0].relationships.create(:name => "goes_well_with", :value => "Earring",
                                        :company => @sparklies, :property_definition => @text_property)
      @products[1].relationships.create(:name => "used_on", :value => "ABC0", :company => @sparklies)
      @products[2].relationships.create(:name => "used_on", :value => "ABC0", :company => @tinselies)
    end
    
    after(:all) do
      @sparklies.destroy
      @tinselies.destroy
      
      @products.each do |product|
        product.relationships.destroy!
        product.values.destroy!
        product.destroy
      end
    end
    
    it "should yield the the Sparklies clasp (used) and the Sparklies Earring for the Sparklies necklace" do
      Relationship.related_products(@products[0]).should == {
        "uses" => [ @products[1] ],
        "goes_well_with" => [ @products[2] ]
      }
    end
    
    it "should yield the Sparklies necklace (used) for the Sparklies clasp" do
      Relationship.related_products(@products[1]).should == { "used_on" => [ @products[0] ] }
    end
    
    it "should yield the Sparklies necklace (goes well) for the Sparklies Earring" do
      Relationship.related_products(@products[2]).should == { "goes_well_with" => [ @products[0] ] }
    end

    it "should yield no related products for the Tinselies clasp" do
      Relationship.related_products(@products[3]).should == {}
    end
    
    it "should yield no related products for the Tinselies earring" do
      Relationship.related_products(@products[4]).should == {}
    end
  end
  
end