require "rubygems"
require "merb-core"
require "spec" # Satisfies Autotest and anyone else not using the Rake tasks
 
# this loads all plugins required in your init file so don't add them
# here again, Merb will do it for you
Merb.start_environment(:testing => true, :adapter => 'runner', :environment => ENV['MERB_ENV'] || 'test')
 
Spec::Runner.configure do |config|
  # config.include(Merb::Test::ViewHelper)
  # config.include(Merb::Test::RouteHelper)
  # config.include(Merb::Test::ControllerHelper)
end

DataMapper.auto_migrate! if Merb.orm == :datamapper

class BeValid
  def initialize
    
  end
  
  def matches?(model)
    @model = model
    return @model.valid?
  end
  
  def description
    "be valid"
  end
  
  def failure_message
    (["expected to be valid, but was not..."] + @model.errors.full_messages.map { |m| " - #{m}" }).join("\n")
  end
  
  def negative_failure_message
    "expected to be invalid, but was not - missing validation?"
  end
end

def be_valid
  BeValid.new
end
