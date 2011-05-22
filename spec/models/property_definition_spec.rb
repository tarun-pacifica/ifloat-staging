require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe PropertyDefinition do

  describe "creation" do   
    before(:each) do
      @property = PropertyDefinition.new(:property_type_id => 1, :name => "physical:size", :sequence_number => 1)
    end
    
    it "should succeed with valid data" do
      @property.should be_valid
    end
    
    it "should fail without a property type" do
      @property.property_type = nil
      @property.should_not be_valid
    end
    
    it "should fail without a key" do
      @property.name = nil
      @property.should_not be_valid
    end
    
    it "should fail with an invalid key" do
      @property.name = "weight"
      @property.should_not be_valid
    end
    
    it "should fail without a sequence number" do
      @property.sequence_number = nil
      @property.should_not be_valid
    end
  end
  
  describe "friendly naming" do
    before(:all) do
      @property = PropertyDefinition.create(:property_type_id => 1, :name => "appearance:colour", :sequence_number => 1)
    end
    
    after(:all) do
      @property.destroy
    end
    
    after(:each) do
      @property.translations.destroy!
    end
    
    it "should be the split property name in the absence of any translations" do
      @property.friendly_name_sections("ENG").should == ["appearance", "colour"]
    end
    
    it "should be the split property name in the absence of the requested translation" do
      @property.translations.create(:language_code => "FRA", :value => "Aspect:Couleur")
      @property.friendly_name_sections("ENG").should == ["appearance", "colour"]
    end
    
    it "should be the split translation value when present" do
      @property.translations.create(:language_code => "ENG", :value => "Appearance:Colour")
      @property.friendly_name_sections("ENG").should == ["Appearance", "Colour"]
    end
  end
  
end