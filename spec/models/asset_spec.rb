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
      proc { @asset.url(:small) }.should_not raise_error
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
    
    it "should fail without an unknown view" do
      @asset.view = "top-bottom"
      @asset.should_not be_valid
    end
    
    it "should succeeed without source notes" do
      @asset.source_notes = nil
      @asset.should be_valid
    end
  end
    
  describe "chaining" do
    before(:all) do
      @asset = Asset.create(:company_id => 1, :bucket => "products", :name => "car___1.jpg")
    end
    
    after(:all) do
      @asset.destroy
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
    
    it "should succeed with the same chain but a different sequence number" do
      Asset.new(:company_id => 1, :bucket => "products", :name => "car___2.jpg").should be_valid
    end
    
    it "should fail with an unknown chain and sequence number > 1" do
      Asset.new(:company_id => 1, :bucket => "products", :name => "bike___2.jpg").should_not be_valid
    end
  end
  
  describe "chain retrieval" do
    before(:all) do
      @assets = ["car___1.jpg", "car___2.jpg", "car___3.jpg", "bike___1.jpg", "bike___2.jpg"].map do |name|
        Asset.create(:company_id => 1, :bucket => "products", :name => name)
      end
    end
    
    after(:all) do
      @assets.each { |asset| asset.destroy }
    end
    
    it "should return the complete, in-order chain for all primary asset IDs specified" do
      asset_ids = [0, 4].map { |i| @assets[i].id }
      chains_by_id = Asset.chains_by_id(asset_ids)
      car1_id = asset_ids.first
      chains_by_id.keys.should == [car1_id]
      chains_by_id[car1_id].map { |asset| asset.id }.should == [1, 2].map { |i| @assets[i].id }
    end
  end
  
  describe "file path" do
    before(:all) { @asset = Asset.new(:file_path => "car.jpg", :file_path_small => "cars.jpg") }
    
    it "should succeed with valid data" do
      @asset.file_path.should == "car.jpg"
    end
    
    it "should succeed with valid data and a variant" do
      @asset.file_path(:small).should == "cars.jpg"
    end
    
    it "should succeed with valid data and an unset variant (returning nil)" do
      @asset.file_path(:tiny).should be_nil
    end
    
    it "should succeed with valid data and an unknown variant (returning nil)" do
      @asset.file_path(:silly).should be_nil
    end
  end
  
  describe "store name" do
    before(:each) { @asset = Asset.new(:bucket => "products", :name => "car.jpg", :checksum => "abc") }
    
    it "should succeed with valid data" do
      @asset.store_name.should =~ /abc.jpg$/
    end
    
    it "should succeed with valid data and a variant" do
      @asset.store_name(:small).should =~ /abc-small.jpg$/
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
  
  describe "store names" do
    it "should return the nominal store name for a non-image asset" do
      names = Asset.new(:bucket => "products", :name => "car.pdf", :checksum => "abc").store_names
      names.size.should == 1
      names.first.should =~ /abc.pdf$/
    end
    
    it "should return the nominal and small/tiny variants for an image asset" do
      names = Asset.new(:bucket => "products", :name => "car.jpg", :checksum => "abc").store_names
      names.size.should == 3
      names[0].should =~ /abc.jpg$/
      names[1].should =~ /abc-small.jpg$/
      names[2].should =~ /abc-tiny.jpg$/
    end
  end

end
