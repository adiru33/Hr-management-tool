Rails.application.routes.draw do
  root "home#show"

  namespace :api, defaults: { format: :json } do
    resource :session, only: %i[show create destroy]
  end
  get "up" => "rails/health#show", as: :rails_health_check
end
