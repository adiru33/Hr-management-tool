class HrAccountMailer < ActionMailer::Base
  def reset_password_instructions(account, token, _options = {})
    @reset_url = Rails.application.routes.url_helpers.password_reset_url(
      token: token, **Rails.configuration.action_mailer.default_url_options
    )
    mail(to: account.email, subject: "Reset your ACME Salary Management password")
  end
end
