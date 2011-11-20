require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Banner do

  describe "creation" do
    before(:each) do
      @banner = Banner.new(
      :asset_id    => 1,
      :description => "foo",
      :link_url    => "foo",
      :custom_html => "<p></p>",
      :location    => "header",
      :height      => 300,
      :width       => 400
    )
    end
    
    it "should succeed with valid data" do
      @banner.should be_valid
    end
    
    it "should fail without an asset" do
      @banner.asset = nil
      @banner.should_not be_valid
    end
    
    it "should fail without a description" do
      @banner.description = nil
      @banner.should_not be_valid
    end
    
    it "should succeed without a link URL" do
      @banner.link_url = nil
      @banner.should be_valid
    end
    
    it "should succeed without custom HTML" do
      @banner.custom_html = nil
      @banner.should be_valid
    end
    
    it "should fail with a location" do
      @banner.location = nil
      @banner.should_not be_valid
    end
    
    it "should fail with an invalid location" do
      @banner.location = "neptune"
      @banner.should_not be_valid
    end
    
    it "should succeed without a height" do
      @banner.height = nil
      @banner.should be_valid
    end
    
    it "should succeed without a width" do
      @banner.width = nil
      @banner.should be_valid
    end
  end
  
  describe "html" do
    before(:all) do
      @asset = Asset.new(:bucket => "banners", :name => "foo", :checksum => "1234")
    end
    
    it "should return the custom HTML if provided" do
      Banner.new(:custom_html => "foo").html.should == "foo"
    end
    
    it "should return the image HTML if no link URL is provided" do
      Banner.new(:asset => @asset).html.should ==
        "<img src=\"http://localhost:4000/assets/banners/1234\" border=\"0\" width=\"0\" height=\"0\" />"
    end
    
    it "should return the wrapped image HTML if a link URL is provided" do
      Banner.new(:asset => @asset, :link_url => "foo").html.should ==
        "<a href=\"foo\" target=\"new\"> <img src=\"http://localhost:4000/assets/banners/1234\" border=\"0\" width=\"0\" height=\"0\" /> </a>"
    end
  end

end