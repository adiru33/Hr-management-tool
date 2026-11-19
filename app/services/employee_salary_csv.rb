require "csv"

class EmployeeSalaryCsv
  PROFILE_HEADERS = %w[employee_number full_name country_code department job_role joined_on last_working_on].freeze
  SALARY_HEADERS = %w[
    effective_on status currency annual_base_salary previous_currency previous_annual_base_salary change_amount change_percent
  ].freeze

  def initialize(employee, as_of:)
    @employee = employee
    @timeline = EmployeeSalaryTimeline.new(employee, as_of: as_of)
  end

  def generate
    employee = @employee
    profile = [
      employee.employee_number, employee.full_name, employee.country_code, employee.department.name, employee.job_role.name
    ].map { |value| spreadsheet_text(value) } + [employee.joined_on, employee.last_working_on]

    # The UTF-8 marker lets Excel recognize non-ASCII names when opening the file directly.
    "\uFEFF" + CSV.generate(force_quotes: true, row_sep: "\r\n") do |csv|
      csv << PROFILE_HEADERS + SALARY_HEADERS
      csv << profile + Array.new(SALARY_HEADERS.length) if @timeline.entries.empty?
      @timeline.entries.each { |entry| csv << profile + salary_cells(entry) }
    end
  end

  private

  def salary_cells(entry)
    salary = entry.salary
    previous = entry.previous
    change = entry.change
    precision = SalaryRecord::CURRENCY_PRECISIONS.fetch(salary.currency_code)

    [
      salary.effective_on, entry.status, salary.currency_code, decimal(salary.amount_minor, precision),
      previous&.currency_code,
      previous && decimal(previous.amount_minor, SalaryRecord::CURRENCY_PRECISIONS.fetch(previous.currency_code)),
      change && decimal(change.fetch(:amount_minor), precision),
      change && decimal(entry.percentage_hundredths, 2)
    ]
  end

  def decimal(amount, precision)
    sign = amount.negative? ? "-" : ""
    whole, remainder = amount.abs.divmod(10**precision)
    return "#{sign}#{whole}" if precision.zero?

    "#{sign}#{whole}.#{remainder.to_s.rjust(precision, '0')}"
  end

  def spreadsheet_text(value)
    # A visible prefix keeps formula-like profile text inert when a spreadsheet opens the export.
    return "Text: #{value}" if /\A(?:[\t\r\n]|[[:space:]'\uFEFF]*[=+\-@＝＋－＠])/.match?(value)

    value
  end
end
