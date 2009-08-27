require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe PropertyValue do
  
  describe "creation" do
    it "should fail" do
      PropertyValue.new.should_not be_valid
    end
  end

end