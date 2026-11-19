class HrAccount < ApplicationRecord
  belongs_to :employee, inverse_of: :hr_account
  has_secure_password

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :employee_id, uniqueness: true

  def active_on?(date)
    employee.employed_on?(date)
  end
end
