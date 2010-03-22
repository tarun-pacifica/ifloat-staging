# merb -i -r "lib/ensure_users_and_blogs"

require "pp"

def whiny_save(object)
  return object if object.save
  puts "Failed to save #{object.class}..."
  pp object.attributes
  object.errors.full_messages.each { |m| puts " - #{m}" }
  exit 1
end

# Users

users = [
  {:name => "Andre Ben Hamou", :nickname => "Andre", :login => "andre@bluetheta.com", :password => "fl04t3r", :admin => true},
  {:name => "Tom Cunliffe", :nickname => "Tom", :login => "snugberth@aol.com", :password => "ab5fd34"},
  {:name => "Graeme Clark", :nickname => "Graeme", :login => "graeme.clark@att.biz", :password => "TND7%$58", :admin => true},
  {:name => "William Mackay", :nickname => "William", :login => "w.mackay@clear.net.nz", :password => "ff51641ea"},
  {:name => "Michael Allan", :nickname => "Michael", :login => "mhjallan@googlemail.com", :password => "tr33fr0g", :admin => true}
]

users.each do |info|
  info[:created_from] = "0.0.0.0"
  
  user = User.first(:login => info[:login])
  if user.nil?
    user = User.new(info.update(:confirmation => info[:password]))
  else
    info.delete(:password) if Password.match?(user.password, info[:password])
    user.attributes = info
  end
  whiny_save(user)
end

# Blogs (and Articles)

tom = User.first(:login => "snugberth@aol.com")
toms_blog = tom.blogs.first(:name => "tom_cunliffe")
if toms_blog.nil?
  toms_blog = tom.blogs.new(:company => Company.first(:reference => "GBR-04426357"),
                            :name => "tom_cunliffe",
                            :email => "info@tomcunliffe.com",
                            :primary_url => "www.tomcunliffe.com",
                            :call_to_action => "Find books by Tom")
  toms_blog.description = "After a lifetime of cruising, teaching, examining and skippering to high levels, I find I am often asked for guidance or an opinion. Sometimes this may be an 'expert opinion' to be used in a legal dispute, but often a private client merely wishes to save trouble and expense by tapping into my experience."
  whiny_save(toms_blog)
end
