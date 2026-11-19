Devise.setup do |config|
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.stretches = Rails.env.test? ? 1 : 12
  config.password_length = 12..72
  config.email_regexp = URI::MailTo::EMAIL_REGEXP
  config.paranoid = true
  config.reset_password_within = 30.minutes
  config.sign_in_after_reset_password = false
  config.mailer = "HrAccountMailer"
end

require "devise/orm/active_record"
