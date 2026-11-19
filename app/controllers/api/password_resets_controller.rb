module Api
  class PasswordResetsController < BaseController
    before_action :require_password_recovery
    rate_limit to: 5, within: 15.minutes, only: :create, name: "request", with: -> { rate_limited }
    rate_limit to: 10, within: 15.minutes, only: :update, name: "complete", with: -> { rate_limited }

    def create
      email = params[:email]
      if email.is_a?(String) && email.bytesize <= 254 && URI::MailTo::EMAIL_REGEXP.match?(email.strip)
        RequestPasswordResetJob.perform_later(email)
      end

      render json: { message: "If an eligible account matches that email, a reset link will be sent." }, status: :accepted
    end

    def update
      input = params.permit(:token, :password, :password_confirmation)
      token, password, confirmation = input.values_at(:token, :password, :password_confirmation)
      return invalid_link unless token.is_a?(String) && /\A[A-Za-z0-9_-]{1,128}\z/.match?(token)
      unless password.is_a?(String) && password.length >= 12 && password.bytesize <= 72 && password == confirmation
        return render json: { error: "Enter matching passwords with at least 12 characters and at most 72 bytes." },
          status: :unprocessable_entity
      end

      reset = HrAccount.transaction do
        account = HrAccount.with_reset_password_token(token)
        if account&.sign_in_allowed_on?(business_date) && account.reset_password_period_valid?
          account.reset_password_and_revoke_sessions(password, confirmation)
        end
      end
      return invalid_link unless reset

      sign_out(:hr_account)
      reset_session
      render json: { message: "Password updated. Sign in with your new password.", csrfToken: form_authenticity_token }
    end

    private

    def require_password_recovery
      return if Rails.configuration.x.password_recovery.enabled

      render json: { error: "Email password recovery is unavailable." }, status: :service_unavailable
    end

    def invalid_link
      render json: { error: "This reset link is invalid or expired. Request a new link." }, status: :unprocessable_entity
    end

    def rate_limited
      render json: { error: "Too many attempts. Try again in a few minutes." }, status: :too_many_requests
    end
  end
end
