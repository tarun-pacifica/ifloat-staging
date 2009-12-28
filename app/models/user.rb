# = Summary
#
# The User class strictly models actual people (i.e. not automated accounts or such like). The Employee subclass adds some business-related information to Users.
#
# User names are recorded as a single string in order to avoid messy problems with international names that obey different rules to European ones. Additionally, users may optionally record a nickname, should they wish to mask their true name from other site users.
#
# All users have a login (of a current, working e-mail address) and a hashed password.
#
# User preferences as to whether they wish to receive marketing materials are also tracked by this class.
#
# === Sample Data
#
# name:: 'Joe Bloggs'
# nickname:: 'Bloggsy
# login:: 'joe.bloggs@example.org'
#
class User
  include DataMapper::Resource
  
  property :id, Serial
  property :name, String, :required => true
  property :nickname, String
  property :login, String, :length => 255, :required => true, :format => :email_address, :unique => true
  property :password, String, :length => 255, :required => true
  property :admin, Boolean, :default => false
  property :disabled_at, DateTime
  property :send_marketing, Boolean, :default => false
  
  has n, :blogs
  has n, :cached_finds
  has n, :contacts
  has n, :future_purchases, :order => [:created_at]
  has n, :locations
  has n, :products, :model => "UserProduct"
  has n, :purchases
  # TODO has n, :root_products
  
  before :valid? do
    self.login = login.downcase unless login.nil?
  end
  
  # TODO: spec (and add password checks to spec given now not nullable)
  def self.authenticate(login, pass)
    user = User.first(:login => login)
    return nil if user.nil?
    Password.match?(user.password, pass) ? user : nil
  end
  
  attr_reader :plain_password
  
  def display_name
    nickname || name
  end
  
  def enabled?
    disabled_at.nil? or disabled_at > DateTime.now
  end
  
  # TODO: spec
  def reset_password
    self.password, @plain_password = Password.ensure(nil)
  end
end
