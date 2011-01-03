class Users < Application
  redact_params :password, :confirmation
  
  def confirm(id, confirm_key)
    user = User.get(id)
    return redirect("/") if user.nil? or confirm_key != user.confirm_key or not user.confirmed_at.nil?
    
    user.confirmed_at = DateTime.now
    user.save
    
    render
  end
  
  def create(name, nickname, login, password, confirmation)
    nickname = nil if nickname.blank?    
    user = User.new(:name => name, :nickname => nickname, :login => login, :password => password, :confirmation => confirmation, :created_from => request.remote_ip)
    user.valid?
    errors = user.errors.full_messages
    
    if errors.empty?
      if user.save
        Mailer.deliver(:registration, :user => user)
        session.login!(login, password)
        "<p>Successfully registered and logged in as <strong>#{user.name}</strong>. Confirmation e-mail sent to <strong>#{login}</strong>.</p>"
      else raise Unauthenticated, "Unable to register, please try again later"
      end
    else
      raise Unauthenticated, errors.join("\n")
    end
  end
  
  def login(submit, login, password)
    if submit == "Reset Password"
      raise Unauthenticated, "Specify an account" if login.blank?
      user = User.first(:login => login)
      raise Unauthenticated, "Unknown account" if user.nil?
      
      user.reset_password
      user.save
      
      Mailer.deliver(:password_reset, :user => user)
      "<p>Password reset e-mail sent to <strong>#{login}</strong>.</p>"
      
    else
      raise Unauthenticated, "Specify an account and password" if login.blank? or password.blank?
      session.login!(login, password)
      "<p>Successfully logged in as <strong>#{session.user.name}</strong>.</p>"
      
    end
  end
  
  def logout
    session.logout
    ""
  end
  
  def me
    (session.authenticated? ? session.user.attributes.keep(:name, :nickname) : {}).to_json
  end
end
