require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Attachment do
  
  def set_parentage(attachment, combination)
    attachment.cached_find_id    = (combination & 1) > 0 ? 1 : nil
    attachment.product_id        = (combination & 2) > 0 ? 1 : nil
  end

  describe "creation" do
    before(:each) do
      @attachment = Attachment.new(:asset_id => 1, :product_id => 1, :role => "image", :sequence_number => 1)
    end
    
    it "should succeed with valid data" do
      @attachment.should be_valid
    end
    
    it "should fail without an asset" do
      @attachment.asset = nil
      @attachment.should_not be_valid
    end
    
    it "should succeed with either a cached_find or a product" do
      [1, 2].each do |combination|
        set_parentage(@attachment, combination)
        @attachment.should be_valid
      end
    end
    
    it "should fail without a cached_find or a product" do
      set_parentage(@attachment, 0)
      @attachment.should_not be_valid
    end
    
    it "should fail with both a cached_find and a product" do
      set_parentage(@attachment, 3)
      @attachment.should_not be_valid
    end
    
    it "should fail without a role" do
      @attachment.role = nil
      @attachment.should_not be_valid
    end
    
    it "should fail with an unkown role" do
      @attachment.role = "father"
      @attachment.should_not be_valid
    end
    
    it "should fail without a sequence number" do
      @attachment.sequence_number = nil
      @attachment.should_not be_valid
    end
  end
  
  describe "creation with existing attachment (of the same role) for a given product" do
    before(:all) do
      @attachment = Attachment.create(:asset_id => 1, :product_id => 1, :role => "image", :sequence_number => 1)
    end
    
    after(:all) do
      @attachment.destroy
    end
    
    it "should succeed with a different sequence number" do
      Attachment.new(:asset_id => 1, :product_id => 1, :role => "image", :sequence_number => 2).should be_valid
    end
    
    it "should fail with the same sequence number" do
      Attachment.new(:asset_id => 1, :product_id => 1, :role => "image", :sequence_number => 1).should_not be_valid
    end
  end

end