class Prelaunch < Application
  # TODO: get rid of @hide_title support in application.html.erb
  def login
    return redirect("/") if session.authenticated?
    render
  end
end
