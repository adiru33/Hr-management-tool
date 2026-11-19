class HomeController < ApplicationController
  def show
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer" if request.path == password_reset_path
  end
end
