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

    def current_account
      return @current_account if defined?(@current_account)

      account = current_hr_account
      valid = account&.sign_in_allowed_on?(business_date) && account.access_version == session[:access_version]
      if !valid && (account || session[:access_version] || session[:hr_account_id])
        sign_out(:hr_account)
        reset_session
      end
      @current_account = valid ? account : nil
    end

    def require_hr_account
      require_role("hr_manager", "HR Manager")
    end

    def require_access_admin
      require_role("access_admin", "Access Admin")
    end

    def require_role(role, label)
      if current_account.nil?
        render json: { error: "Sign in to continue.", csrfToken: form_authenticity_token }, status: :unauthorized
      elsif current_account.role != role
        render json: { error: "#{label} access is required.", code: "wrong_role", accountRole: current_account.role },
          status: :forbidden
      end
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
