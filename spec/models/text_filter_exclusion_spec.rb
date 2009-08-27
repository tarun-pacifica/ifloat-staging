require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe TextFilterExclusion do

  describe "creation" do   
    before(:each) do
      @exclusion = TextFilterExclusion.new(:text_filter_id => 1, :value => "beans")
    end
    
    it "should succeed with valid data" do
      @exclusion.should be_valid
    end
    
    it "should fail without a text filter" do
      @exclusion.text_filter = nil
      @exclusion.should_not be_valid
    end
    
    it "should fail without a value" do
      @exclusion.value = nil
      @exclusion.should_not be_valid
    end
  end
  
  describe "creation with existing exclusion" do
    before(:all) do
      @exclusion = TextFilterExclusion.create(:text_filter_id => 1, :value => "beans")
    end
    
    after(:all) do
      @exclusion.destroy
    end
    
    it "should succeed with a different text filter" do
      TextFilterExclusion.new(:text_filter_id => 2, :value => "beans").should be_valid
    end
    
    it "should succeed with a different value" do
      TextFilterExclusion.new(:text_filter_id => 1, :value => "toast").should be_valid
    end
    
    it "should fail with the same text filter and value" do
      TextFilterExclusion.new(:text_filter_id => 1, :value => "beans").should_not be_valid
    end
  end

end