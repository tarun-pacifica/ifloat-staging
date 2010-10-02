require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe AssociatedWord do

  describe "creation" do   
    before(:each) do
      @aw = AssociatedWord.new(:word => "silly", :implied_by => {5 => "fatuous", 6 => "spurious"})
    end
    
    it "should succeed with valid data" do
      @aw.should be_valid
    end
    
    it "should fail without a word" do
      @aw.word = nil
      @aw.should_not be_valid
    end
    
    it "should fail without a rule" do
      @aw.implied_by = nil
      @aw.should_not be_valid
    end
    
    it "should fail with any blank rule words" do
      @aw.implied_by[6] = ""
      @aw.should_not be_valid
    end
    
    it "should fail with any non-string rule words" do
      @aw.implied_by[6] = nil
      @aw.should_not be_valid
    end
    
    it "should fail with any non-integer rule keys" do
      @aw.implied_by["foo"] = "bar"
      @aw.should_not be_valid
    end
  end

end