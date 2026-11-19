class SalaryRecord < ApplicationRecord
  CURRENCY_PRECISIONS = { "EUR" => 2, "GBP" => 2, "INR" => 2, "JPY" => 0, "USD" => 2 }.freeze

  belongs_to :employee
  belongs_to :recorded_by_hr_account, class_name: "HrAccount"

  normalizes :currency_code, with: ->(code) { code.strip.upcase }

  validates :currency_code, inclusion: { in: CURRENCY_PRECISIONS.keys }
  validates :amount_minor, numericality: { only_integer: true, greater_than: 0 }
  validates :effective_on, presence: true, uniqueness: { scope: :employee_id }
  validate :validate_employment_date
  validate :validate_author

  def self.minor_units_for(amount, currency_code)
    precision = CURRENCY_PRECISIONS[currency_code]
    raise ArgumentError, "Unsupported currency" unless precision

    decimals = precision.zero? ? "" : "(?:\\.[0-9]{1,#{precision}})?"
    unless /\A[0-9]+#{decimals}\z/.match?(amount.to_s)
      raise ArgumentError, "Enter an amount with at most #{precision} decimal places"
    end

    units = (BigDecimal(amount.to_s) * (10**precision)).to_i
    raise ArgumentError, "Amount is outside the supported range" unless units.between?(1, (2**63) - 1)

    units
  end

  def readonly?
    persisted? || super
  end

  def status(on: Date.current)
    return :unapplied unless employee.employed_on?(effective_on)

    effective_on > on ? :scheduled : :effective
  end

  def change_from(previous)
    return unless previous && previous.currency_code == currency_code && employee.employed_on?(effective_on)

    difference = amount_minor - previous.amount_minor
    { amount_minor: difference, percentage: Rational(difference * 100, previous.amount_minor) }
  end

  private

  def validate_employment_date
    return unless employee && effective_on
    return if employee.employed_on?(effective_on)

    errors.add(:effective_on, "must be within the employee's employment dates")
  end

  def validate_author
    return unless employee && recorded_by_hr_account

    if !recorded_by_hr_account.role_hr_manager?
      errors.add(:base, "Only an HR Manager can record salary changes")
    elsif recorded_by_hr_account.employee_id == employee.id
      errors.add(:base, "HR managers cannot change their own salary")
    end
  end
end
