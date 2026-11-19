module Api
  class BaseController < ApplicationController
    before_action :prevent_caching
    rescue_from ActionController::InvalidAuthenticityToken, with: :invalid_csrf_token
    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    private

    def prevent_caching
      response.headers["Cache-Control"] = "no-store"
    end

    def business_date
      @business_date ||= Date.current
    end

    def current_hr_account
      return @current_hr_account if defined?(@current_hr_account)

      account = HrAccount.includes(:employee).find_by(id: session[:hr_account_id]) if session[:hr_account_id]
      @current_hr_account = account if account&.active_on?(business_date)
      reset_session if !@current_hr_account && session[:hr_account_id]
      @current_hr_account
    end

    def require_hr_account
      return if current_hr_account

      render json: { error: "Sign in to continue.", csrfToken: form_authenticity_token }, status: :unauthorized
    end

    def invalid_csrf_token
      prevent_caching
      render json: { error: "Your security token expired. Please try again.", csrfToken: form_authenticity_token },
        status: :unprocessable_entity
    end

    def not_found
      render json: { error: "Record not found." }, status: :not_found
    end
  end
end
