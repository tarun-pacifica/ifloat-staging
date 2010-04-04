module Mailer
  ADDRESSES = {
    :admin => "admin@ifloat.biz",
    :sysadmin => "andre@bluetheta.com"
  }
  
  def self.deliver(action, params)
    case action
    
    when :exception
      exception = params[:exception]
      whilst = params[:whilst]
      return if exception.nil? or whilst.nil?
      
      backtrace = (exception.backtrace || []).join("\n")
      context = "#{whilst} on #{`hostname`.chomp} (#{Merb.environment} environment)"
      
      Mail.deliver do |mail|
        Mailer.envelope(mail, action, :admin, :sysadmin)
        body ["Context: #{context}", "#{exception.class}: #{exception}", backtrace].join("\n\n")
      end
      
    when :password_reset
      user = params[:user]
      return if user.nil?
      
      Mail.deliver do |mail|
        Mailer.envelope(mail, action, :admin, user.login)
        Mailer.user_body(mail, user, ["Your ifloat password has been reset to...", user.plain_password].join("\n\n"))
      end
      
    when :registration
      user = params[:user]
      return if user.nil?
      
      confirmation_link =
        Merb::Config[:registration_host] +
        Merb::Router.url(:user_confirm, :id => user.id, :confirm_key => user.confirm_key)

      Mail.deliver do |mail|
        Mailer.envelope(mail, action, :admin, user.login)
        Mailer.user_body(mail, user, ["Thanks for registering with ifloat. Please visit the following link within #{User::UNCONFIRMED_EXPIRY_HOURS} hours to make your account permanent...", confirmation_link].join("\n\n"))
      end
    
    else raise "Unknown mail delivery action #{action.inspect}"  
    
    end
  end
  
  def self.envelope(mail, action, from_address, to_address)
    from_address, to_address = [from_address, to_address].map do |address|
      address.is_a?(Symbol) ? ADDRESSES[address] : address
    end
    
    mail[:from] = from_address
    mail[:to] = to_address
    
    mail[:subject] = "ifloat " + action.to_s.split("_").map { |word| word.capitalize }.join(" ")
  end
  
  def self.user_body(mail, user, message)
    content = <<-TEXT
      Dear #{user.name},

      #{message}

      Best regards,

      The ifloat Support Team
      #{ADDRESSES[:admin]}
    TEXT
    
    mail[:body] = content.lines.map { |line| line.lstrip }.join("\n")
  end
end