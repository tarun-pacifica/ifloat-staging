require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Employee do

  describe "creation" do   
    before(:each) do
      @employee = Employee.new(:facility_id => 1,
                               :name => "Michael Jackson",
                               :nickname => "MJ",
                               :login => "mj@example.com",
                               :password => "sekrit",
                               :confirmation => "sekrit",
                               :job_title => "Manager",
                               :department => "MIS",
                               :created_from => "10.0.0.1")
    end
    
    it "should succeed with valid data" do
      @employee.should be_valid
    end
    
    it "should fail without a facility" do
      @employee.facility = nil
      @employee.should_not be_valid
    end
    
    it "should succeed without a job title" do
      @employee.job_title = nil
      @employee.should be_valid
    end
    
    it "should succeed without a department" do
      @employee.department = nil
      @employee.should be_valid
    end
  end

end