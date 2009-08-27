# = Summary
#
# This is a centralized logger for errors in controllers. It has no data integrity rules as the emphasis is on getting something / anything recorded in the event of a problem.
#
# = Processes
#
# === 1. Destroy Obsolete Data
#
# Run ControllerError.obsolete.destroy! periodically. This will destroy all ControllerErrors older than OBSOLESCENCE_TIME.
#
class ControllerError
  include DataMapper::Resource
  
  OBSOLESCENCE_TIME = 1.month
  
  property :id, Serial
  property :created_at, DateTime, :default => proc { DateTime.now }
  
  property :controller, String
  property :action, String
  property :params, Yaml
  
  property :exception_class, String
  property :exception_message, String, :size => 255
  property :exception_context, String, :size => 255
  
  property :ip_address, IPAddress
  property :session, Yaml
  
  def self.log!(request)
    exception = (request.exceptions.first rescue Exception.new("request.exceptions.first"))
    request_params = (request.params.to_hash rescue {})
    
    create( :controller => request_params["controller"],
            :action     => request_params["action"],
            :params     => request_params,
            
            :exception_class   => exception.class,
            :exception_message => exception.message,
            :exception_context => (exception.backtrace || []).first,
            
            :ip_address => (request.remote_ip rescue nil),
            :session    => (request.session.to_hash rescue nil) )
  end
  
  def self.obsolete
    all(:created_at.lt => OBSOLESCENCE_TIME.ago)
  end
end
