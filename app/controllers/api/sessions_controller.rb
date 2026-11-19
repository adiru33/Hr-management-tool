module Api
  class SessionsController < BaseController
    rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
      render json: { error: "Too many sign-in attempts. Try again in a few minutes." }, status: :too_many_requests
    }

    def show
      render_session(current_account)
    end

    def create
      credentials = params.permit(:email, :password)
      account = authenticate_credentials(credentials[:email], credentials[:password])

      unless account&.sign_in_allowed_on?(business_date)
        return render json: { error: "The email or password is incorrect, or your account access is inactive." },
          status: :unauthorized
      end

      reset_session
      sign_in(:hr_account, account, force: true)
      session[:access_version] = account.access_version
      render_session(account)
    end

    def destroy
      sign_out(:hr_account)
      reset_session
      render_session(nil)
    end

    private

    def authenticate_credentials(email, password)
      return unless email.is_a?(String) && email.present? && email.bytesize <= 254
      return unless password.is_a?(String) && password.present? && password.bytesize <= 72

      account = HrAccount.find_for_database_authentication(email: email)
      if account
        account if account.valid_password?(password)
      else
        # Perform the same bcrypt work when the email has no matching account.
        HrAccount.new.password = password
        nil
      end
    end

    def render_session(account)
      render json: {
        account: account && { name: account.employee.full_name, role: account.role },
        passwordRecoveryAvailable: Rails.configuration.x.password_recovery.enabled,
        csrfToken: form_authenticity_token
      }
    end
  end
end
