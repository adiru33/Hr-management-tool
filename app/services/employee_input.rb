class EmployeeInput
  class InvalidInput < StandardError; end

  PROFILE_FIELDS = %i[full_name country_code department job_role].freeze
  HIRE_FIELDS = (PROFILE_FIELDS + %i[employee_number joined_on annual_salary currency]).freeze

  def initialize
    @departments = Department.all.index_by { |department| department.name.downcase }
    @job_roles = JobRole.all.index_by { |job_role| job_role.name.downcase }
  end

  def profile(input)
    {
      full_name: text(input[:full_name], "name", maximum: 120),
      country_code: input[:country_code],
      department: lookup(@departments, input[:department], "department"),
      job_role: lookup(@job_roles, input[:job_role], "job role")
    }
  end

  def hire!(input, actor:)
    number = text(input[:employee_number], "employee number", maximum: 50)
    unless /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/.match?(number)
      raise InvalidInput, "Employee number may contain letters, numbers, periods, underscores, and hyphens."
    end

    currency = input[:currency].to_s.strip.upcase
    amount = text(input[:annual_salary], "annual salary", maximum: 32)
    begin
      amount_minor = SalaryRecord.minor_units_for(amount, currency)
    rescue ArgumentError => error
      raise InvalidInput, error.message
    end

    Employee.hire!(
      attributes: profile(input).merge(employee_number: number, joined_on: self.class.date(input[:joined_on], "joining date")),
      salary: { amount_minor: amount_minor, currency_code: currency },
      recorded_by: actor
    )
  end

  def self.date(value, label)
    return Date.iso8601(value) if value.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(value)

    raise InvalidInput, "Enter a valid #{label} in YYYY-MM-DD format."
  rescue Date::Error
    raise InvalidInput, "Enter a valid #{label} in YYYY-MM-DD format."
  end

  private

  def lookup(options, value, label)
    options.fetch(value.to_s.strip.downcase) { raise InvalidInput, "Choose an existing #{label}." }
  end

  def text(value, label, maximum:)
    if value.is_a?(String) && value.strip.present? && value.strip.length <= maximum
      return value.strip
    end

    raise InvalidInput, "Enter a #{label} with at most #{maximum} characters."
  end
end
