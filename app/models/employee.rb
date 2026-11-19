class Employee < ApplicationRecord
  COUNTRY_CODES = %w[DE GB IN JP US].freeze

  belongs_to :department
  belongs_to :job_role
  has_one :hr_account, inverse_of: :employee
  has_many :salary_records

  normalizes :employee_number, with: ->(number) { number.strip.upcase }
  normalizes :full_name, with: ->(name) { name.strip }
  normalizes :country_code, with: ->(code) { code.strip.upcase }

  validates :employee_number, presence: true
  # CSV imports check existing numbers in batches and retain the database uniqueness constraint.
  validates :employee_number, uniqueness: true, unless: -> { validation_context == :csv_import }
  validates :full_name, :joined_on, presence: true
  validates :country_code, inclusion: { in: COUNTRY_CODES }
  validates :last_working_on, comparison: { greater_than_or_equal_to: :joined_on },
    if: -> { joined_on.present? && last_working_on.present? }

  scope :active_on, ->(date) do
    where("joined_on <= ?", date).where("last_working_on IS NULL OR last_working_on >= ?", date)
  end

  def self.in_organization(country: nil, department: nil, role: nil)
    employees = all
    employees = employees.where(country_code: country) if country.present?
    employees = employees.where(department: Department.where(name: department)) if department.present?
    employees = employees.where(job_role: JobRole.where(name: role)) if role.present?
    employees
  end

  def self.organization_options
    {
      countries: COUNTRY_CODES,
      departments: Department.order(:name).pluck(:name),
      roles: JobRole.order(:name).pluck(:name)
    }
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

  def record_departure!(date, as_of: Date.current)
    with_lock do
      was_active = employed_on?(as_of)
      update!(last_working_on: date)
      hr_account&.increment!(:access_version) if was_active != employed_on?(as_of)
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
