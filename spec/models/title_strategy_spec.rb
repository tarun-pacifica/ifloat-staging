require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe TitleStrategy do
  
  describe "creation" do
    before(:each) do
      template = ["reference:class", "-", "product.reference"]
      @title = TitleStrategy.new(:class_name => "boat", :canonical => template, :description => template, :image => template)
    end
    
    it "should succeed with valid data" do
      @title.should be_valid
    end
    
    it "should fail without a class name" do
      @title.class_name = nil
      @title.should_not be_valid
    end
    
    it "should fail without a canonical title" do
      @title.canonical = nil
      @title.should_not be_valid
    end
    
    it "should fail without a description title" do
      @title.description = nil
      @title.should_not be_valid
    end
    
    it "should fail without a image title" do
      @title.image = nil
      @title.should_not be_valid
    end
    
    it "should fail with an invalid template" do
      @title.image << ["foo"]
      @title.should_not be_valid
    end
  end
  
end