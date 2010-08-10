# = Summary
#
# Blogs are collections of articles with an overarching name, description, contact e-mail address and primary URL.
#
# === Sample Data
#
# name:: 'michael_jackson'
# description:: 'Lorem ipsum dolor sit amet, consectetur adipisicing elit.'
# email:: 'mj@example.com'
# primary_url:: 'www.example.com'
#
class Blog
  include DataMapper::Resource
  
  property :id, Serial
  property :name, String, :required => true, :unique_index => true
  property :description, Text, :lazy => false
  property :email, String, :length => 255, :format => :email_address
  property :primary_url, String, :length => 255
  property :call_to_action, String, :length => 255
  
  belongs_to :company
  belongs_to :user
  has n, :articles, :order => [:created_at.desc]
end
