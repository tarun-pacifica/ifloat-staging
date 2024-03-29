module Mailer
  ADDRESSES = {
    :admin     => "admin@ifloat.biz",
    :prodadmin => "admin@ifloat.biz",
    :sysadmin  => "andre@bluetheta.com"
  }
  
  def self.deliver(action, params)
    case action
    
    when :exception
      exception, whilst = params.values_at(:exception, :whilst)
      return if exception.nil? or whilst.nil?
      
      backtrace = (exception.backtrace || []).join("\n")
      
      Mail.deliver do |mail|
        Mailer.envelope(mail, action, :admin, :sysadmin)
        body ["Context: #{Mailer.context(whilst)}", "#{exception.class}: #{exception}", backtrace].join("\n\n")
      end
    
    when :facility_import_success
      whilst, attachment_path = params.values_at(:whilst, :attach)
      return if whilst.nil? or attachment_path.nil?
      
      report = ["Context: #{Mailer.context(whilst)}", ""]
      Mail.deliver do |mail|
        Mailer.envelope(mail, action, :admin, :prodadmin)
        body report.join("\n")
        add_file attachment_path unless attachment_path.nil?
      end
    
    when :password_reset
      user = params[:user]
      return if user.nil?
      
      Mail.deliver do |mail|
        Mailer.envelope(mail, action, :admin, user.login)
        Mailer.user_body(mail, user, ["Your ifloat password has been reset to...", user.plain_password].join("\n\n"))
      end
    
    when :purchase_completed
      purchase, userish = params.values_at(:purchase, :userish)
      return if purchase.nil? or userish.nil?
      facility, response = purchase.facility, purchase.response
      
      report = ["Purchase #{purchase.id} completed at #{facility.primary_url} from #{purchase.ip_address} (#{userish})"]
      report << "Date: #{purchase.completed_at.strftime('%B %d, %Y at %H:%M:%S')}"
      report << "#{facility.name} reference: #{response[:reference].inspect}"
      report << "Total: #{response.values_at(:total, :currency).join(' ').inspect}"
      report << ""
      report << "Items..."
      report += response[:items].map { |item| item.inspect }
      
      Mail.deliver do |mail|
        Mailer.envelope(mail, action, :admin, :admin)
        body report.join("\n")
      end
    
    when :purchase_started
      values = params.values_at(:url, :picks, :from_ip, :userish)
      return if values.any? { |v| v.nil? }
      url, picks, from_ip, userish = values
      
      product_ids = picks.map { |pick| pick.product_id }
      products_by_id = Product.all(:id => product_ids).hash_by(:id)
      companies_by_id = Company.all(:id => products_by_id.values.map { |product| product.company_id }).hash_by(:id)
      
      report = ["Purchase started at #{url} from #{from_ip} (#{userish})"]
      report << ""
      
      report << "Picks..."
      report += picks.map do |pick|
        product = products_by_id[pick.product_id]
        company = companies_by_id[product.company_id]
        "(#{pick.group}) #{company.reference} / #{product.reference} [#{pick.cached_class}]"
      end.sort
      
      Mail.deliver do |mail|
        Mailer.envelope(mail, action, :admin, :admin)
        body report.join("\n")
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
  
  def self.context(whilst)
    "#{whilst} on #{`hostname`.chomp} (#{Merb.environment} environment)"
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
