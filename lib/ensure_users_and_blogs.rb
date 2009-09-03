# merb -i -r "lib/ensure_users_and_blogs"

require "pp"

def whiny_save(object)
  return object if object.save
  puts "Failed to save #{object.klass}..."
  pp object.attributes
  object.errors.full_messages.each { |m| puts " - #{m}" }
  exit 1
end

# Users

tom = User.first(:login => "snugberth@aol.com")
if tom.nil?
  tom = User.new(:name => "Tom Cunliffe",
                 :nickname => "Tom",
                 :login => "snugberth@aol.com",
                 :password => Password.hash("tom"))
  whiny_save(tom)
end

graeme = User.first(:login => "graeme.clark@att.biz")
if graeme.nil?
  graeme = User.new(:name => "Graeme Clark",
                    :nickname => "Graeme",
                    :login => "graeme.clark@att.biz",
                    :password => Password.hash("TND7%$58"))
  whiny_save(graeme)
end



# Blogs (and Articles)

toms_blog = tom.blogs.first(:name => "tom_cunliffe")
if toms_blog.nil?
  toms_blog = tom.blogs.new(:company => Company.first(:reference => "GBR-04426357"),
                            :name => "tom_cunliffe",
                            :email => "info@tomcunliffe.com",
                            :primary_url => "www.tomcunliffe.com")
  toms_blog.description = "After a lifetime of cruising, teaching, examining and skippering to high levels, I find I am often asked for guidance or an opinion. Sometimes this may be an 'expert opinion' to be used in a legal dispute, but often a private client merely wishes to save trouble and expense by tapping into my experience."
  whiny_save(toms_blog)
end
