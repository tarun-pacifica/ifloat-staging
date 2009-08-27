require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Purchase do

  describe "creation" do   
    before(:each) do
      @purchase = Purchase.new(:facility_id => 1, :user_id => 1, :product_refs => ["ABC12345"])
    end
    
    it "should succeed with valid data" do
      @purchase.should be_valid
    end
    
    it "should fail without a facility" do
      @purchase.facility = nil
      @purchase.should_not be_valid
    end
    
    it "should succeed without a user" do
      @purchase.user = nil
      @purchase.should be_valid
    end
    
    it "should fail without product references" do
      @purchase.product_refs = nil
      @purchase.should_not be_valid
    end
    
    it "should fail with an empty set of product references" do
      @purchase.product_refs = []
      @purchase.should_not be_valid
    end
    
    it "should fail with at least one invalid product reference" do
      @purchase.product_refs = ["", "ABC12345"]
      @purchase.should_not be_valid
    end
  end
  
  it "should have specs for the other parts of the purchase process"
  
  describe "abandonment" do
    before(:all) do
      now = DateTime.now
      recent, old = 2.minutes.ago, (Purchase::OBSOLESCENCE_TIME + 2.minutes).ago

      @purchases = [[recent, nil], [recent, now], [old, nil], [old, now]].map do |created, completed|
       Purchase.create(:facility_id => 1, :created_at => created, :completed_at => completed, :product_refs => ["AB12345"])
      end
    end

    after(:all) do
      @purchases.each { |purchase| purchase.destroy }
    end

    it "should abandon only those purchases that have not been completed inside the obsolescence time" do
      Purchase.abandon_obsolete
      @purchases.each_with_index do |purchase, i|
        purchase.reload
        if i.zero? then purchase.completed_at.should == nil
        else purchase.completed_at.should_not == nil
        end
        purchase.abandoned.should == [false, false, true, false][i]
      end
    end
  end
end