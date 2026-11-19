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
      email = credentials[:email]
      password = credentials[:password]
      account = HrAccount.authenticate_by(email: email, password: password) if
        email.is_a?(String) && email.bytesize <= 254 && password.is_a?(String) && password.bytesize <= 72

      unless account&.sign_in_allowed_on?(business_date)
        return render json: { error: "The email or password is incorrect, or your account access is inactive." },
          status: :unauthorized
      end

      reset_session
      session[:hr_account_id] = account.id
      session[:access_version] = account.access_version
      render_session(account)
    end

    def destroy
      reset_session
      render_session(nil)
    end

    private

    def render_session(account)
      render json: {
        account: account && { name: account.employee.full_name, role: account.role },
        csrfToken: form_authenticity_token
      }
    end
  end
end
