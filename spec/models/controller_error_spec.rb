require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe ControllerError do
  
  # no creation testing as ControllerErrors have no integrity checks
  # this ensures that _something_ always gets written if it possibly can be
  
  describe "logging" do
    after(:all) do
      ControllerError.all.destroy!
    end
    
    it "should succeed with nil" do
      ControllerError.log!(nil).should be_valid
    end
    
    it "should succeed with a request" do
      request = mock( "request",
                      :exceptions => [Exception.new("oh dear")],
                      :params => {"controller" => "fishes", "action" => "new", "id" => 42},
                      :remote_ip => "10.0.0.1",
                      :session => {"fish_food_eaten" => "22 nibbles"} )
      ControllerError.log!(request).should be_valid
    end
  end

  describe "should be classified as" do
    before(:all) do
      recent, old = 2.minutes.ago, (ControllerError::OBSOLESCENCE_TIME + 2.minutes).ago
      @errors = [recent, old].map { |created_at| ControllerError.create(:created_at => created_at) }
    end
    
    after(:all) do
      @errors.each { |error| error.destroy }
    end
    
    it "obsolete if created longer ago than OBSOLESCENCE_TIME" do
      ControllerError.obsolete.count.should == 1
    end
  end

end