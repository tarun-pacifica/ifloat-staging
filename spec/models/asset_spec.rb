require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Asset do
  
  describe "creation" do
    before(:each) do
      @asset = Asset.new(:company_id => 1, :bucket => "products", :name => "car.jpg")
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
