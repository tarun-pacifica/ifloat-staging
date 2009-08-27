require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Contact do

  describe "creation" do
    it "should fail" do
      Contact.new.should_not be_valid
    end
  end

end