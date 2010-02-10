class Application < Merb::Controller
  before :ensure_authenticated, :exclude => [:login]
  
  def self._filter_params(params)
    redacted = params.dup
    (@redacted_params || []).each { |key| redacted[key] = "[REDACTED]" }
    redacted
  end
  
  def self.redact_params(*params)
    @redacted_params = params
  end
  
  def ensure_authenticated
    redirect "/prelaunch/login" unless params[:action] == "track" or Merb.environment == "development" or session.authenticated?
  end
end
