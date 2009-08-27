class MainMailer < Merb::MailController

  def password_reset
    @user = params[:user]
    render_mail
  end
  
  def registration
    @user = params[:user]
    render_mail
  end
  
end
