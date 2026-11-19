Rails.application.routes.draw do
  root "home#show"

  namespace :api, defaults: { format: :json } do
    resource :session, only: %i[show create destroy]
    resources :employees, only: %i[index show], param: :number
  end
  get "up" => "rails/health#show", as: :rails_health_check
end
