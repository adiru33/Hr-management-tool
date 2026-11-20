module Api
  class SessionsController < BaseController
    rate_limit to: 10, within: 3.minutes, only: %i[create update], with: -> {
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

      start_session(account)
      render_session(account)
    end

    def update
      account = current_account
      return render json: { error: "Sign in to continue." }, status: :unauthorized unless account

      input = params.permit(:password, :password_confirmation)
      password, confirmation = input.values_at(:password, :password_confirmation)
      unless password.is_a?(String) && password.length >= 12 && password.bytesize <= 72 && password == confirmation
        return render json: { error: "Enter matching passwords with at least 12 characters and at most 72 bytes." },
          status: :unprocessable_entity
      end

      result = account.with_lock do
        if !account.sign_in_allowed_on?(business_date) || account.access_version != session[:access_version]
          :expired
        elsif !account.password_change_required?
          :not_required
        elsif account.reset_password_and_revoke_sessions(password, confirmation, complete_setup: true)
          :updated
        end
      end

      case result
      when :expired
        destroy
      when :not_required
        render json: { error: "This account has already completed password setup." }, status: :forbidden
      when :updated
        start_session(account)
        render_session(account)
      else
        render json: { error: "Choose a password different from your temporary password." }, status: :unprocessable_entity
      end
    end

    def destroy
      sign_out(:hr_account)
      reset_session
      render_session(nil)
    end

    private

    def start_session(account)
      reset_session
      sign_in(:hr_account, account, force: true)
      session[:access_version] = account.access_version
    end

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
        account: account && {
          name: account.employee.full_name, role: account.role, passwordChangeRequired: account.password_change_required?
        },
        passwordRecoveryAvailable: Rails.configuration.x.password_recovery.enabled,
        csrfToken: form_authenticity_token
      }
    end
  end
end
