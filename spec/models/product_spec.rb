require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Product do

  describe "creation" do
    it "should fail" do
      Product.new.should_not be_valid
    end
  end
  
end
