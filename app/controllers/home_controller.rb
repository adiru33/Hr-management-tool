class HomeController < ApplicationController
  def show
    response.headers["Cache-Control"] = "no-store"
  end
end
