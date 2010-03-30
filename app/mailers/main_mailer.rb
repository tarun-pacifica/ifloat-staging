class MainMailer < Merb::MailController
  def exception
    context = params[:context] || "<none>"
    exception = params[:exception]
    (["Context: #{context}", "", "#{exception.class}: #{exception}", ""] + exception.backtrace).join("\n")
  end

  def password_reset
    @user = params[:user]
    render_mail
  end
  
  def registration
    @user = params[:user]
    render_mail
  end
  
end
