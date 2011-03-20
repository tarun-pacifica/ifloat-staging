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
    response = {:messages => session.unqueue_messages}
    response.update(session.user.attributes.keep(:name, :nickname)) if session.authenticated?
    response.to_json
  end
  
  def track(url)
    session.log!("GET", url, request.remote_ip) if
      case url
      when "/"                       then true
      when %r(^/brands/(.+?)/(.+?)$) then valid_category_path($2) and not Brand.first(:name => $1).nil?
      when %r(^/brands/(.+?)/?$)     then not Brand.first(:name => $1).nil?
      when %r(^/categories/?$)       then true
      when %r(^/categories/(.+?)$)   then valid_category_path($1)
      when %r(^/products/.*?(\d+)$)  then Indexer.product_url($1.to_i) == url
      else false
      end
    ""
  end
  
  
  private
  
  def valid_category_path(path)
    Indexer.category_children_for_node(path.split("/").map { |name| name.tr("+", " ") }).any?
  end
end
