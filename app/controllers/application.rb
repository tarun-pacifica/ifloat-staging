class Application < Merb::Controller
  before :ensure_authenticated, :exclude => [:login]
  
  def ensure_authenticated
    redirect "/prelaunch/login" unless params[:action] == "track" or Merb.environment == "development" or session.authenticated?
  end
end
