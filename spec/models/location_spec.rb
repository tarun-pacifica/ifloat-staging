require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Location do

  describe "creation" do   
    before(:each) do
      @location = Location.new(:user_id => 1,
                               :country_code => "GBR",
                               :postal_address => "5 Test Street",
                               :gps_coordinates => "25.12315x7.13849",
                               :gln_13 => 61414000017)
    end
    
    it "should succeed with valid data" do
      @location.should be_valid
    end
    
    it "should succeed without a user" do
      @location.user = nil
      @location.should be_valid
    end
    
    it "should fail without a country code" do
      @location.country_code = nil
      @location.should_not be_valid
    end
    
    it "should fail with an invalid country code" do
      @location.country_code = "England"
      @location.should_not be_valid
    end
    
    it "should succeed without a postal address" do
      @location.postal_address = nil
      @location.should be_valid
    end
    
    it "should fail with invalid GPS coordinates" do
      @location.gps_coordinates = "5 by 7"
      @location.should_not be_valid
    end
    
    it "should succeed without a GLN" do
      @location.gln_13 = nil
      @location.should be_valid
    end
    
    it "should fail with an invalid GLN" do
      @location.gln_13 = 53142
      @location.should_not be_valid
    end
  end

end