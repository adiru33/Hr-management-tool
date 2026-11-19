class RequestPasswordResetJob < ActiveJob::Base
  self.log_arguments = false

  def perform(email)
    account = HrAccount.find_for_database_authentication(email: email)
    account.send_reset_password_instructions if account&.sign_in_allowed_on?(Date.current)
  end
end
