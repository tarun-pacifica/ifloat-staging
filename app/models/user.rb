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
# = Processes
#
# === 1. Destroy Unconfirmed Users
#
# Run User.expired.destroy! periodically. This will destroy any users who have failed to confirm their registration within UNCONFIRMED_EXPIRY_HOURS hours.
#
class User
  include DataMapper::Resource
  
  UNCONFIRMED_EXPIRY_HOURS = 24
  
  # TODO: update spec with field definitions
  property :id,             Serial
  property :name,           String,    :required => true
  property :nickname,       String
  property :login,          String,    :required => true, :length => 255, :format => :email_address, :unique => true, :unique_index => true
  property :password,       String,    :required => true, :length => 255
  property :admin,          Boolean,   :required => true, :default => false
  property :disabled_at,    DateTime
  property :send_marketing, Boolean,   :required => true, :default => false
  property :created_at,     DateTime,  :required => true, :default => proc { DateTime.now }
  property :created_from,   IPAddress, :required => true
  # TODO: spec
  property :confirm_key,    String,    :required => true, :default => proc { Password.gen_string(16) }
  property :confirmed_at,   DateTime
  
  has n, :blogs
  has n, :cached_finds
  has n, :contacts
  has n, :picked_products, :order => [:created_at]
  has n, :locations
  has n, :purchases
  
  before :valid? do
    self.login = login.downcase unless login.nil?
  end
  
  # TODO: spec
  validates_with_block :password, :if => proc { |u| u.attribute_dirty?(:password) and not u.password.blank? } do
    (password == @confirmation) || [false, "Password doesn't match confirmation"]
  end
  
  # TODO: spec
  before :save do
    unless Password.hashed?(password)
      @plain_password = password
      self.password = Password.hash(@plain_password)
    end
  end
  
  # TODO: spec (and add password checks to spec given now not nullable)
  def self.authenticate(login, pass)
    user = User.first(:login => login)
    return nil if user.nil?
    Password.match?(user.password, pass) ? user : nil
  end
  
  # TODO: spec
  def self.expired
    all(:confirmed_at => nil, :created_at.lt => UNCONFIRMED_EXPIRY_HOURS.hours.ago)
  end
  
  attr_reader :plain_password
  attr_writer :confirmation
  
  def display_name
    nickname || name
  end
  
  def enabled?
    disabled_at.nil? or disabled_at > DateTime.now
  end
  
  # TODO: spec
  def reset_password
    @plain_password = Password.gen_string(8)
    self.password = Password.hash(@plain_password)
  end
end
