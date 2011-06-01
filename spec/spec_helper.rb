require "merb-core"

Merb.start_environment(:testing => true, :adapter => 'runner', :environment => ENV['MERB_ENV'] || 'test')

RSpec.configure do |config|
  # config.include(Merb::Test::ViewHelper)
  # config.include(Merb::Test::RouteHelper)
  # config.include(Merb::Test::ControllerHelper)
end

# TODO: reactivate once this isn't a 5 second bottleneck
DataMapper::Model.descendants.each do |model|
  begin
    # model.auto_migrate!
  rescue
    warn "auto_migration failed on #{model}"
  end
end if Merb.orm == :datamapper

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
