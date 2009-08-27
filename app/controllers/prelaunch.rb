class Prelaunch < Application
  # TODO: remove for launch (and get rid of @hide_title support in application.html.erb)
  def login
    redirect("/") if session.authenticated?
    @hide_title = true
    render
  end
end