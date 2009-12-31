# = Summary
#
# An Employee is a User subclass that belongs to a Facility and records an optional job title and department.
#
# === Sample Data
#
# job_title:: 'Sales Director'
# department:: 'Sales'
#
class Employee < User
  property :job_title, String
  property :department, String
  
  belongs_to :facility, :required => false
  
  validates_present :facility_id
end
