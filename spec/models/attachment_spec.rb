require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Attachment do
  
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
    
    it "should fail without a product" do
      @attachment.product = nil
      @attachment.should_not be_valid
    end
    
    it "should fail without a role" do
      @attachment.role = nil
      @attachment.should_not be_valid
    end
    
    it "should fail with an unknown role" do
      @attachment.role = "father"
      @attachment.should_not be_valid
    end
    
    it "should fail without a sequence number" do
      @attachment.sequence_number = nil
      @attachment.should_not be_valid
    end
  end
  
  describe "asset retrieval for products" do
    before(:all) do      
      @bike, @car = %w(BIKE CAR).map { |ref| Product.create(:company_id => 1, :reference => ref) }
      
      @assets = %w(bike.jpg car.jpg car_plans.png).map do |name|
        asset = Asset.create(:company_id => 1, :bucket => "products", :name => name)
        case name
        when "bike.jpg"      then @bike.attachments.create(:asset => asset, :role => "image", :sequence_number => 1)
        when "car.jpg"       then @car.attachments.create(:asset => asset, :role => "image", :sequence_number => 1)
        when "car_plans.png" then @car.attachments.create(:asset => asset, :role => "dimensions", :sequence_number => 1)
        end
        asset
      end
    end
    
    after(:all) do
      [@car, @bike].each do |product|
        product.attachments.destroy!
        product.destroy
      end
      @assets.each { |asset| asset.destroy }
    end
    
    it "should return the all assets by role, product IDs specified" do
      product_ids = [@car.id]
      assets_by_role_by_product_id = Attachment.product_role_assets(product_ids)
      assets_by_role_by_product_id.keys.should == product_ids
      assets_by_role = assets_by_role_by_product_id[product_ids.first]
      assets_by_role.keys.sort.should == %w(dimensions image)
      assets_by_role["image"].map { |asset| asset.id }.should == [@assets[1].id]
      assets_by_role["dimensions"].map { |asset| asset.id }.should == [@assets[2].id]
    end
  end

end