require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Asset do
  
  describe "creation" do   
    before(:each) do
      @asset = Asset.new(:company_id => 1,
                         :bucket => "articles",
                         :name => "car.jpg",
                         :description => "2004 Red Volvo Estate",
                         :view => "top-left",
                         :source_notes => "What Car? Magazine, January 2005, Page 22")
    end
    
    it "should succeed with valid data" do
      @asset.should be_valid
      @asset.checksum = "abc"
      proc { @asset.url }.should_not raise_error
    end
    
    it "should fail without a company" do
      @asset.company = nil
      @asset.should_not be_valid
    end
    
    it "should fail without a bucket" do
      @asset.bucket = nil
      @asset.should_not be_valid
    end
    
    it "should fail without a name" do
      @asset.name = nil
      @asset.should_not be_valid
    end
    
    it "should succeed without a description" do
      @asset.description = nil
      @asset.should be_valid
    end
    
    it "should succeed without a view" do
      @asset.view = nil
      @asset.should be_valid
    end
    
    it "should fail without an unkown view" do
      @asset.view = "top-bottom"
      @asset.should_not be_valid
    end
    
    it "should succeeed without source notes" do
      @asset.source_notes = nil
      @asset.should be_valid
    end
    
    it "should fail with an invalid chain ID" do
      @asset.chain_id = 1
      @asset.should_not be_valid
    end
    
    it "should fail with a sequence number (in the absence of a chain ID)" do
      @asset.chain_sequence_number = 1
      @asset.should_not be_valid
    end
  end
  
  describe "creation with existing asset" do
    before(:all) do
      @asset = Asset.create(:company_id => 1, :bucket => "products", :name => "car.jpg")
    end
    
    after(:all) do
      @asset.destroy
    end
    
    it "should succeed with a different name for the same bucket" do
      Asset.new(:company_id => 1, :bucket => "products", :name => "foo.jpg").should be_valid
    end
    
    it "should succeed with a different name for a different bucket" do
      Asset.new(:company_id => 1, :bucket => "articles", :name => "foo.jpg").should be_valid
    end
    
    it "should fail with the same name for the same bucket" do
      Asset.new(:company_id => 1, :bucket => "products", :name => "car.jpg").should_not be_valid
    end
    
    it "should succeed with the same name for a different bucket" do
      Asset.new(:company_id => 1, :bucket => "articles", :name => "car.jpg").should be_valid
    end
    
    it "should succeed with the asset's chain ID and a sequence number" do
      Asset.new(:company_id => 1, :bucket => "products", :name => "car2.jpg",
                :chain_id => @asset.id, :chain_sequence_number => 1).should be_valid
    end
    
    it "should fail with the asset's chain ID but no sequence number" do
      Asset.new(:company_id => 1, :bucket => "products", :name => "car2.jpg",
                :chain_id => @asset.id).should_not be_valid
    end
  end
  
  describe "chaining" do
    before(:all) do
      @asset1 = Asset.create(:company_id => 1, :bucket => "products", :name => "car1.jpg")
      @asset2 = Asset.create(:company_id => 1, :bucket => "products", :name => "car2.jpg",
                             :chain_id => @asset1.id, :chain_sequence_number => 1)
    end
    
    after(:all) do
      @asset1.destroy
      @asset2.destroy
    end
    
    it "(basic parsing) should return the root name and chain sequence number given a valid, chained name" do
      Asset.parse_chain("abc___5.jpg").should == ["abc___1.jpg", 5]
    end
    
    it "(basic parsing) should return the root name and 0 given a valid, non-chained name" do
      Asset.parse_chain("abc.jpg").should == ["abc___1.jpg", 0]
    end
    
    it "(basic parsing) should return nil given an invalid name" do
      Asset.parse_chain("$$$").should == nil
    end
    
    it "should succeed with the same chain ID but a different sequence number" do
      Asset.new(:company_id => 1, :bucket => "products", :name => "car3.jpg",
                :chain_id => @asset1.id, :chain_sequence_number => 2).should be_valid
    end
    
    it "should fail with the same chain ID and sequence number" do
      Asset.new(:company_id => 1, :bucket => "products", :name => "car3.jpg",
                :chain_id => @asset1.id, :chain_sequence_number => 1).should_not be_valid
    end
  end
  
  describe "store name" do
    before(:each) { @asset = Asset.new(:bucket => "products", :name => "car.jpg", :checksum => "abc") }
    
    it "should succeed with valid data" do
      proc { @asset.store_name }.should_not raise_error
    end
    
    it "should fail without a bucket" do
      @asset.bucket = nil
      proc { @asset.store_name }.should raise_error
    end
    
    it "should fail without a name" do
      @asset.name = nil
      proc { @asset.store_name }.should raise_error
    end
    
    it "should fail without a checksum" do
      @asset.checksum = nil
      proc { @asset.store_name }.should raise_error
    end
  end

end
