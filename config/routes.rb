Rails.application.routes.draw do
  root "home#show"

  namespace :api, defaults: { format: :json } do
    resource :session, only: %i[show create destroy]
    resource :compensation, only: :show
    resources :access_accounts, only: %i[index update]
    resources :employees, only: %i[index show create update], param: :number, format: false,
      constraints: { number: /[^\/]+/ } do
      patch :departure, on: :member
      post :import, on: :collection
    end
    post "employees/:number/salary_records", to: "employees#create_salary", as: :employee_salary_records,
      format: false, constraints: { number: /[^\/]+/ }
  end
  get "up" => "rails/health#show", as: :rails_health_check
end
