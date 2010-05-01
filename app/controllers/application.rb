class Application < Merb::Controller
  RANGE_SEPARATOR = " <em>to</em> "
  
  before :ensure_authenticated, :exclude => [:login, :track]
  
  def self._filter_params(params)
    redacted = params.dup
    (@redacted_params || []).each { |key| redacted[key] = "[REDACTED]" }
    redacted
  end
  
  def self.redact_params(*params)
    @redacted_params = params
  end
  
  def ensure_authenticated
    raise Unauthenticated if Merb.environment == "staging" and not session.authenticated?
  end
end
