class Employee < ApplicationRecord
  COUNTRY_CODES = %w[DE GB IN JP US].freeze

  belongs_to :department
  belongs_to :job_role
  has_one :hr_account, inverse_of: :employee
  has_many :salary_records

  normalizes :employee_number, with: ->(number) { number.strip.upcase }
  normalizes :full_name, with: ->(name) { name.strip }
  normalizes :country_code, with: ->(code) { code.strip.upcase }

  validates :employee_number, presence: true, uniqueness: true
  validates :full_name, :joined_on, presence: true
  validates :country_code, inclusion: { in: COUNTRY_CODES }
  validates :last_working_on, comparison: { greater_than_or_equal_to: :joined_on },
    if: -> { joined_on.present? && last_working_on.present? }

  scope :active_on, ->(date) do
    where("joined_on <= ?", date).where("last_working_on IS NULL OR last_working_on >= ?", date)
  end

  def self.hire!(attributes:, salary:, recorded_by:)
    transaction do
      employee = create!(attributes)
      employee.salary_records.create!(
        **salary, effective_on: employee.joined_on, recorded_by_hr_account: recorded_by
      )
      employee
    end
  end

  def employed_on?(date)
    joined_on.present? && joined_on <= date && (last_working_on.nil? || last_working_on >= date)
  end

  def current_salary(on: Date.current)
    return unless employed_on?(on)

    salary_records.where(effective_on: ..on).order(effective_on: :desc).first
  end
end
