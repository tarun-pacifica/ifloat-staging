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
  property :params, Object

  property :exception_class, String
  property :exception_message, String, :length => 255
  property :exception_context, String, :length => 255

  property :ip_address, IPAddress
  property :session, Object

  def self.log!(request)
    begin
      exception = request.exceptions.first rescue nil
      exception ||= Exception.new("request.exceptions.first")

      params = request.params.to_hash rescue {}

      create({
               :controller => params["controller"].to_s,
               :action     => params["action"].to_s,
               :params     => params,
               :exception_class   => exception.class.to_s,
               :exception_message => exception.message.to_s[0..254], # Respect the length limit
               :exception_context => (exception.backtrace || []).first.to_s[0..254],
               :ip_address => request.remote_ip rescue nil,
               :session    => (request.session.to_hash rescue {})
      })
    rescue => e
      # Fail silently since this is just error logging
      Merb.logger.error("Failed to log controller error: #{e.message}")
      nil
    end
  end

  def self.obsolete
    all(:created_at.lt => OBSOLESCENCE_TIME.ago)
  end
end
