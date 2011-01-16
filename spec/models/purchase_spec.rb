require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Purchase do

  describe "creation" do
    before(:each) do
      @purchase = Purchase.new(:facility_id => 1, :session_id => "a", :user_id => 1, :ip_address => "10.0.0.1", :response => {:items => []})
    end
    
    it "should succeed with valid data" do
      @purchase.should be_valid
    end
    
    it "should fail without a facility" do
      @purchase.facility = nil
      @purchase.should_not be_valid
    end
    
    it "should fail without a session" do
      @purchase.session = nil
      @purchase.should_not be_valid
    end
    
    it "should succeed without a user" do
      @purchase.user = nil
      @purchase.should be_valid
    end
    
    it "should fail without an IP address" do
      @purchase.ip_address = nil
      @purchase.should_not be_valid
    end
    
    it "should fail without a response" do
      @purchase.response = nil
      @purchase.should_not be_valid
    end
  end
  
  describe "parsing a response" do
    it "should return {:items => []} with empty params" do
      Purchase.parse_response({}).should == {:items => []}
    end
    
    it "should reflect the currency, reference and total" do
      data = {:currency => "GBP", :reference => "abcd1234", :total => "22.50"}
      Purchase.parse_response(Hash[data.map { |k, v| [k.to_s, v] }]).should == data.merge(:items => [])
    end
    
    it "should extract the internal values of each numbered item" do
      data = "reference%3DMLLF05%26name%3DShock%2BCord%2B05mm%26quantity%3D2%26price%3D0.73%26options%3DColour%253A"
      Purchase.parse_response("item_624636" => data)[:items].should == [
        {"reference"=>"MLLF05", "name"=>"Shock Cord 05mm", "price"=>"0.73", "options"=>"Colour:", "quantity"=>"2"}
      ]
    end
  end

end
