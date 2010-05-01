class Exceptions < Merb::Controller
  def action_not_found
    redirect "/"
  end
  
  def common_error
    ControllerError.log!(request)
    exception = request.exceptions.first
    ""
    # "#{exception.status}: #{exception.class.to_s.split('::').last}"
  end
  
  alias :unauthorized   :common_error # 401
  alias :not_found      :common_error # 404
  alias :not_acceptable :common_error # 406
  
  def unauthenticated    
    return redirect("/prelaunch/login") if Merb.environment == "staging" and params[:action] != "login"
    
    @errors = request.exceptions.first.message.split("\n")
    @errors = [] if @errors.first =~ /Unauthenticated/
    @errors.each { |error| error.gsub!(/Login/, "E-mail") }
    render :layout => false
  end
  
  # any other exceptions
  def standard_error
    ControllerError.log!(request)
    raise request.exceptions.first
  end
end