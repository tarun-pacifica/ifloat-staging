class Users < Application
  redact_params :password, :confirmation
  
  def create(name, nickname, login, password, confirmation, challenge)
    nickname = nil if nickname.blank?    
    hashed_password = (password.blank? ? nil : Password.hash(password))
    
    user = User.new(:name => name, :nickname => nickname, :login => login, :password => hashed_password)
    user.valid?
    errors = user.errors.full_messages
    errors << "Password doesn't match confirmation" if (not password.nil?) and password != confirmation
    
    if errors.empty?
      if user.save
        # TODO: reactivate before going live
        # send_mail(MainMailer, :registration,
        #           {:from => "admin@ifloat.biz", :to => user.login, :subject => "iFloat Registration"},
        #           {:user => user})
        session.login!(login, password, challenge)
        "<p>Successfully registered and logged in as <strong>#{user.name}</strong>. Confirmation e-mail sent to <strong>#{login}</strong>.</p>"
      else raise Unauthenticated, "Unable to register, please try again later"
      end
    else
      raise Unauthenticated, errors.join("\n")
    end
  end
  
  def login(submit, login, password, challenge)
    if submit == "Reset Password"
      raise Unauthenticated, "Specify an account" if login.blank?
      user = User.first(:login => login)
      raise Unauthenticated, "Unknown account" if user.nil?
      
      user.reset_password
      user.save
      
      send_mail(MainMailer, :password_reset,
        {:from => "admin@ifloat.biz", :to => user.login, :subject => "iFloat Password Reset"},
        {:user => user})
      "<p>Password reset e-mail sent to <strong>#{login}</strong>.</p>"
      
    else
      raise Unauthenticated, "Specify an account and password" if login.blank? or password.blank?
      session.login!(login, password, challenge)
      "<p>Successfully logged in as <strong>#{session.user.name}</strong>.</p>"
      
    end
  end
  
  def logout
    session.logout
    ""
  end
end