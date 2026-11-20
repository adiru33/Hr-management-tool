Rails.application.routes.draw do
  root "home#show"
  devise_for :hr_accounts, skip: :all
  get "password/reset", to: "home#show", as: :password_reset

  namespace :api, defaults: { format: :json } do
    resource :session, only: %i[show create update destroy]
    resource :password_reset, only: %i[create update]
    resource :compensation, only: :show
    resources :access_accounts, only: %i[index update] do
      get :transfer_candidate, on: :member
    end
    resources :job_roles, only: %i[index create update]
    resources :employees, only: %i[index show create update], param: :number, format: false,
      constraints: { number: /[^\/]+/ } do
      patch :departure, on: :member
      get :salary_history, on: :member
      post :import, on: :collection
    end
    post "employees/:number/salary_records", to: "employees#create_salary", as: :employee_salary_records,
      format: false, constraints: { number: /[^\/]+/ }
  end
  get "up" => "rails/health#show", as: :rails_health_check
end
