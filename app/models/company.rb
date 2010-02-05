# = Summary
#
# A Company represents any organisation with which Pristine does business (and indeed Pristine itself). Aside from it's own data, it is used to collect up Products, Assets and Facilities (and thence Employees and FacilityProducts).
# 
# It is essential that a unique reference be created to identify each Company. This need is particularly apparent if Product references are considered (since the only way to guarantee the unique identification of a Product is via the two-level identifier [company_reference, product_reference]). Hence a Company record contains a reference field. This reference always begins with the pertinent three-character ISO 3166 country code and a hyphen. If the organisation has a registered company number (or reference) then this value should be appended. Otherwise, an underscored version of the company's name should be added. For example...
# 
# GBR-12345:: UK registered company number
# USA-12345:: CAGE number
# DEU-Uber_Alles:: company name as reference
# 
# === Sample Data
# 
# name:: 'Big Boats'
# description:: 'The marine pleasure-craft specialist.'
# reference:: 'GBR-12345'
# primary_url:: 'http://www.bigboats.co.uk'
#
class Company
  include DataMapper::Resource
  
  REFERENCE_FORMAT = /^[A-Z]{3}\-[\w-]+$/
  
  property :id, Serial
  property :name, String, :required => true
  property :description, String, :length => 255
  property :reference, String, :required => true, :format => REFERENCE_FORMAT, :unique => true
  property :primary_url, String, :length => 255

  has n, :assets
  has n, :product_mappings
  has n, :facilities
end
