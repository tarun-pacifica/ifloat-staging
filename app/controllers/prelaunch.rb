class Prelaunch < Application
  # TODO: get rid of @hide_title support in application.html.erb
  def login
    redirect("/") if session.authenticated?
    @hide_title = true
    render
  end
end