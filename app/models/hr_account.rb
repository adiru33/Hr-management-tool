class HrAccount < ApplicationRecord
  belongs_to :employee, inverse_of: :hr_account
  has_secure_password

  enum :role, { employee: "employee", hr_manager: "hr_manager", access_admin: "access_admin" }, prefix: true

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :employee_id, uniqueness: true

  def sign_in_allowed_on?(date)
    !role_employee? && access_enabled? && active_on?(date)
  end

  def active_on?(date)
    employee.employed_on?(date)
  end
end
