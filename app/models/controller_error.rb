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
  property :created_at, DateTime, :required => false
  property :controller, String, :length => 50, :required => false
  property :action, String, :length => 50, :required => false
  property :error_timestamp, DateTime, :required => false
  property :params, Text, :required => false
  property :exception_class, String, :length => 50, :required => false
  property :exception_message, String, :length => 255, :required => false
  property :exception_context, String, :length => 255, :required => false
  property :ip_address, String, :length => 39, :required => false
  property :session, Text, :required => false

  def self.log!(request)
    begin
      exception = (request.exceptions.first rescue Exception.new("request.exceptions.first"))
      request_params = (request.params.to_hash rescue {})

      # Create the object first, then set attributes
      error = new
      error.controller = request_params["controller"].to_s
      error.action = request_params["action"].to_s
      error.params = request_params
      error.exception_class = exception.class.to_s
      error.exception_message = exception.message.to_s[0..254]
      error.exception_context = (exception.backtrace || []).first.to_s[0..254]
      error.ip_address = request.remote_ip.to_s
      error.session = request.session.to_hash
      error.error_timestamp = DateTime.now
      error.created_at = DateTime.now
      error.save
      error
    rescue => e
      Merb.logger.error("Failed to log controller error: #{e.message}")
      nil
    end
  end

  def self.obsolete
    all(:created_at.lt => OBSOLESCENCE_TIME.ago)
  end
end
