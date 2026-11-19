Rails.application.routes.draw do
  root "home#show"

  namespace :api, defaults: { format: :json } do
    resource :session, only: %i[show create destroy]
    resources :access_accounts, only: %i[index update]
    resources :employees, only: %i[index show], param: :number
    post "employees/:number/salary_records", to: "employees#create_salary", as: :employee_salary_records
  end
  get "up" => "rails/health#show", as: :rails_health_check
end
