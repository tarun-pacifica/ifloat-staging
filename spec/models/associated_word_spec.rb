require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe AssociatedWord do

  describe "creation" do   
    before(:each) do
      @aw = AssociatedWord.new(:word => "silly", :rules => {"sometimes" => "fatuous", "usually" => "spurious"})
    end
    
    it "should succeed with valid data" do
      @aw.should be_valid
    end
    
    it "should fail without a word" do
      @aw.word = nil
      @aw.should_not be_valid
    end
    
    it "should fail without a rule" do
      @aw.rules = nil
      @aw.should_not be_valid
    end
    
    it "should fail with any blank rule keys" do
      @aw.rules[""] = "bar"
      @aw.should_not be_valid
    end
    
    it "should fail with any non-string rule keys" do
      @aw.rules[6] = "bar"
      @aw.should_not be_valid
    end
    
    it "should fail with any blank rule words" do
      @aw.rules["sometimes"] = ""
      @aw.should_not be_valid
    end
    
    it "should fail with any non-string rule words" do
      @aw.rules["sometimes"] = nil
      @aw.should_not be_valid
    end
  end

end