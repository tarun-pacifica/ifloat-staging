require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Company do

  describe "creation" do   
    before(:each) do
      @company = Company.new(:name => "Volvo",
                             :description => "A very safe car company.",
                             :reference => "GBR-12345678",
                             :primary_url => "www.volvo.com")
    end
    
    it "should succeed with valid data" do
      @company.should be_valid
    end
    
    it "should fail without a name" do
      @company.name = nil
      @company.should_not be_valid
    end
    
    it "should succeed with a description" do
      @company.description = nil
      @company.should be_valid
    end
    
    it "should fail without a reference" do
      @company.reference = nil
      @company.should_not be_valid
    end
    
    it "should fail with an invalid reference" do
      @company.reference = "PR1234"
      @company.should_not be_valid
    end
    
    it "should succeed without a primary_url" do
      @company.primary_url = nil
      @company.should be_valid
    end
  end

end