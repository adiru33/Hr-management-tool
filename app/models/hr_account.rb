class HrAccount < ApplicationRecord
  belongs_to :employee, inverse_of: :hr_account
  devise :database_authenticatable, :recoverable, :validatable

  enum :role, { employee: "employee", hr_manager: "hr_manager", access_admin: "access_admin" }, prefix: true

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :employee_id, uniqueness: true
  validate :password_fits_bcrypt
  before_update :invalidate_recovery_on_access_revocation, if: -> { will_save_change_to_access_enabled?(to: false) }

  def sign_in_allowed_on?(date)
    !role_employee? && access_enabled? && active_on?(date)
  end

  def active_on?(date)
    employee.employed_on?(date)
  end

  def reset_password_and_revoke_sessions(password, confirmation)
    with_lock do
      next false unless reset_password(password, confirmation)

      increment!(:access_version)
      true
    end
  end

  private

  def invalidate_recovery_on_access_revocation
    # A reset request may have issued a token since this account was loaded.
    reset_password_token_will_change!
    reset_password_sent_at_will_change!
    clear_reset_password_token
  end

  def password_fits_bcrypt
    errors.add(:password, "must be at most 72 bytes") if password && password.bytesize > 72
  end
end
