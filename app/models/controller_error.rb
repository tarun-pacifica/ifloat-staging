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
  property :created_at, DateTime
  property :controller, String, :length => 50
  property :action, String, :length => 50
  property :params, Text
  property :exception_class, String, :length => 50
  property :exception_message, String, :length => 255
  property :exception_context, String, :length => 255
  property :ip_address, String, :length => 39  # Changed from IPAddress to match schema
  property :session, Text
  property :error_timestamp, DateTime

  def self.log!(request)
    begin
      exception = (request.exceptions.first rescue Exception.new("request.exceptions.first"))
      request_params = (request.params.to_hash rescue {})

      create(
        :controller => request_params["controller"],
        :action     => request_params["action"],
        :params     => request_params,
        :exception_class   => exception.class.to_s,
        :exception_message => exception.message.to_s[0..254],
        :exception_context => (exception.backtrace || []).first.to_s[0..254],
        :ip_address => request.remote_ip.to_s,
        :session    => request.session.to_hash,
        :error_timestamp  => DateTime.now,
        :created_at => DateTime.now
      )
    rescue => e
      Merb.logger.error("Failed to log controller error: #{e.message}")
      nil
    end
  end

  def self.obsolete
    all(:created_at.lt => OBSOLESCENCE_TIME.ago)
  end
end
