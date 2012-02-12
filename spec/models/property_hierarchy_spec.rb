require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe PropertyHierarchy do

  describe "creation" do
    before(:each) do
      @hierarchy = PropertyHierarchy.new(:class_name => "foo", :sequence_number => 1, :property_names => ["foo:bar"])
    end
    
    it "should succeed with valid data" do
      @hierarchy.should be_valid
    end
    
    it "should fail without a class name" do
      @hierarchy.class_name = nil
      @hierarchy.should_not be_valid
    end
    
    it "should fail without a sequence number" do
      @hierarchy.sequence_number = nil
      @hierarchy.should_not be_valid
    end
    
    it "should fail without property names" do
      @hierarchy.property_names = nil
      @hierarchy.should_not be_valid
    end
    
    it "should fail with invalid property names" do
      @hierarchy.property_names = "foo:bar,boo:far"
      @hierarchy.should_not be_valid
      @hierarchy.property_names = ["a:1"]
      @hierarchy.should_not be_valid
    end
  end
  
  describe "lead_property_by_seq_num" do
    before(:all) do
      @hierarchies = [
        [1, "boat", %w(prop:one prop:two)],
        [2, "boat", %w(prop:three prop:four)],
        [1, "fish", %w(prop:five prop:six)]
      ].map do |seq_num, class_name, prop_names|
        PropertyHierarchy.create(:sequence_number => seq_num, :class_name => class_name, :property_names => prop_names)
      end
      
      @pdc = Hash[%w(one two three four five six).each_with_index.map { |name, i| [i, {:raw_name => "prop:#{name}"}] }]
    end
    
    before(:each) do
      indexer = mock(:indexer)
      indexer.stub!(:property_display_cache).and_return(@pdc)
      PropertyHierarchy.stub!(:indexer).and_return(indexer)
    end
    
    after(:all) do
      @hierarchies.each(&:destroy)
    end
    
    it "should return the first (indexer) property for the given class for each sequence number" do
      result = PropertyHierarchy.lead_property_by_seq_num("boat")
      result.size.should == 2
      result[1][:raw_name].should == "prop:one"
      result[2][:raw_name].should == "prop:three"
    end
  end

end
