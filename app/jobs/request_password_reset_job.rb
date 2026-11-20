class RequestPasswordResetJob < ActiveJob::Base
  self.log_arguments = false

  def perform(account_id, access_version)
    account = HrAccount.find_by(id: account_id)
    token = account&.issue_password_reset(access_version)
    HrAccountMailer.reset_password_instructions(account, token).deliver_now if token
  end
end
