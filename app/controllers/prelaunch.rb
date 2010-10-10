class Prelaunch < Application
  def login
    session.authenticated? ? redirect("/") : render
  end
end
