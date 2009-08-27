require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe PropertyValueDefinition do

  describe "creation" do
    before(:each) do
      @definition = PropertyValueDefinition.new(:property_type_id => 1, :language_code => "ENG", 
                                                :value => "RAM", :definition => "Random Access Memory")
    end
    
    it "should succeed with valid data" do
      @definition.should be_valid
    end

    it "should fail without a property definition" do
      @definition.property_type = nil
      @definition.should_not be_valid
    end
    
    it "should fail without a language code" do
      @definition.language_code = nil
      @definition.should_not be_valid
    end
    
    it "should fail with an invalid language code" do
      @definition.language_code = "English"
      @definition.should_not be_valid
    end
    
    it "should fail without a value" do
      @definition.value = nil
      @definition.should_not be_valid
    end
    
    it "should fail without a definition" do
      @definition.definition = nil
      @definition.should_not be_valid
    end
  end
  
  describe "creation with existing definition" do
    before(:all) do
      @definition = PropertyValueDefinition.create(:property_type_id => 1, :language_code => "ENG", 
                                                   :value => "RAM", :definition => "Random Access Memory")
    end
    
    after(:all) do
      @definition.destroy
    end
    
    it "should succeed with the same value and language but a different property definition" do
      PropertyValueDefinition.new(:property_type_id => 2, :language_code => "ENG",
                                  :value => "RAM", :definition => "Random Access Memory")
    end
    
    it "should succeed with the same value and property definition but a different language" do
      PropertyValueDefinition.new(:property_type_id => 1, :language_code => "FRA",
                                  :value => "RAM", :definition => "Rouge Arondissement Mourir")
    end
    
    it "should succeed with the same value but a different property definition and language" do
      PropertyValueDefinition.new(:property_type_id => 2, :language_code => "FRA",
                                  :value => "RAM", :definition => "Rouge Arondissement Mourir")
    end
    
    it "should succeed with the same value, property definition and language" do
      PropertyValueDefinition.new(:property_type_id => 1, :language_code => "ENG",
                                  :value => "RAM", :definition => "Random Access Memory")
    end
  end
  
  describe "definitions" do
    before(:all) do
      @colour, @material = ["colour", "material"].map { |n| PropertyType.create(:name => n, :core_type => "text") }
      
      s = 0
      @cid, @mid1, @mid2 = [
        ["colour:simple",  @colour],
        ["material:inner", @material],
        ["material:outer", @material] ].map do |n, type|
          type.definitions.create(:name => n, :sequence_number => s += 1).id
      end
      
      @colour.value_definitions.create(:language_code => "ENG", :value => "Carribean Sunset", :definition => "Red")
      @material.value_definitions.create(:language_code => "ENG", :value => "PTFE", :definition => "Plastic")
    end
    
    after(:all) do
      [@colour, @material].each do |type|
        type.value_definitions.destroy!
        type.definitions.destroy!
        type.destroy
      end
    end
    
    it "should yield an empty hash when passed no property IDs" do
      PropertyValueDefinition.definitions_by_property_id([], "ENG").should == {}
    end
    
    it "should yield an empty hash when passed an unknown language" do
      PropertyValueDefinition.definitions_by_property_id([@cid, @mid1], "FRA").should == {}
    end
    
    it "should yield only the definitions for a given property ID" do
      definitions = PropertyValueDefinition.definitions_by_property_id([@mid1], "ENG")
      definitions[@cid]["Carribean Sunset"].should == nil
      definitions[@mid1].should == {"PTFE" => "Plastic"}
    end
    
    it "should yield the definitions for multiple given property IDs" do
      definitions = PropertyValueDefinition.definitions_by_property_id([@cid, @mid1, @mid2, @mid2 + 10], "ENG")
      definitions[@cid].should == {"Carribean Sunset" => "Red"}
      definitions[@mid1].should == {"PTFE" => "Plastic"}
      definitions[@mid2].should == {"PTFE" => "Plastic"}
      definitions[@mid2 + 10]["PTFE"].should == nil
      definitions[@mid2 + 20]["PTFE"].should == nil
    end
  end

end