module Api
  class EmployeesController < BaseController
    PAGE_SIZE = 25

    before_action :require_hr_account
    rescue_from EmployeeInput::InvalidInput, ActiveRecord::RecordInvalid, with: :invalid_employee
    rescue_from ActiveRecord::StatementTimeout, with: :database_busy

    def index
      employees = filtered_employees
      total = employees.count
      last_page = [(total + PAGE_SIZE - 1) / PAGE_SIZE, 1].max
      page = params[:page].to_s.to_i.clamp(1, last_page)
      entries = employees.includes(:department, :job_role).order(:full_name, :id)
        .offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE)

      render json: {
        employees: entries.map { |employee| summary(employee) },
        page: page,
        pageSize: PAGE_SIZE,
        total: total,
        asOf: business_date,
        filters: Employee.organization_options.merge(
          statuses: %w[Active Former Upcoming],
          currencies: SalaryRecord::CURRENCY_PRECISIONS.keys
        )
      }
    end

    def show
      render json: details(find_employee)
    end

    def create
      employee = EmployeeInput.new.hire!(params.permit(*EmployeeInput::HIRE_FIELDS), actor: current_account)
      render json: details(employee), status: :created
    rescue ActiveRecord::RecordNotUnique
      render json: { error: "That employee number already exists." }, status: :unprocessable_entity
    end

    def import
      result = EmployeeCsvImport.new.call(params[:file], actor: current_account)
      render json: result, status: result[:error] ? :unprocessable_entity : :created
    rescue EmployeeCsvImport::InvalidFile => error
      render json: { error: error.message }, status: :unprocessable_entity
    end

    def update
      employee = find_employee
      employee.update!(EmployeeInput.new.profile(params.permit(*EmployeeInput::PROFILE_FIELDS)))
      render json: details(employee)
    end

    def departure
      employee = find_employee
      if employee.id == current_account.employee_id
        return render json: { error: "An Access Admin or another HR manager must record your departure." },
          status: :forbidden
      end

      last_day = EmployeeInput.date(params[:last_working_on], "last working day")
      employee.record_departure!(last_day, as_of: business_date)
      render json: details(employee)
    end

    def create_salary
      input = params.permit(:amount, :currency, :effective_on)
      currency = input[:currency].to_s.strip.upcase
      effective_on = parse_effective_date(input[:effective_on])
      amount = input[:amount]
      raise ArgumentError, "Enter a valid annual base salary." unless amount.is_a?(String) && amount.bytesize <= 32

      amount_minor = SalaryRecord.minor_units_for(amount.strip, currency)
      employee = Employee.transaction do
        record = find_employee
        record.salary_records.create!(
          amount_minor: amount_minor, currency_code: currency, effective_on: effective_on,
          recorded_by_hr_account: current_account
        )
        record
      end

      render json: details(employee), status: :created
    rescue ActiveRecord::RecordNotUnique
      duplicate_salary
    rescue ActiveRecord::RecordInvalid => error
      if error.record.errors.of_kind?(:effective_on, :taken)
        duplicate_salary
      else
        render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    rescue ArgumentError => error
      render json: { error: error.message }, status: :unprocessable_entity
    end

    private

    def invalid_employee(error)
      message = error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
      render json: { error: message }, status: :unprocessable_entity
    end

    def database_busy
      render json: { error: "The database is busy. Please try again." }, status: :service_unavailable
    end

    def parse_effective_date(value)
      unless value.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(value)
        raise ArgumentError, "Enter a valid effective date."
      end

      Date.iso8601(value)
    rescue Date::Error
      raise ArgumentError, "Enter a valid effective date."
    end

    def duplicate_salary
      render json: { error: "This employee already has a salary record for that effective date." },
        status: :unprocessable_entity
    end

    def filtered_employees
      filters = params.permit(:search, :country, :department, :role, :status)
      employees = Employee.in_organization(country: filters[:country], department: filters[:department], role: filters[:role])
      search = filters[:search].to_s.strip.first(100)

      if search.present?
        pattern = "%#{Employee.sanitize_sql_like(search, "!")}%"
        employees = employees.where(
          "full_name LIKE :pattern ESCAPE '!' OR employee_number LIKE :pattern ESCAPE '!'", pattern: pattern
        )
      end
      case filters[:status]
      when "Active" then employees.active_on(business_date)
      when "Former" then employees.where(last_working_on: ...business_date)
      when "Upcoming" then employees.where("joined_on > ?", business_date)
      else employees
      end
    end

    def find_employee
      Employee.includes(:department, :job_role).find_by!(employee_number: params[:number])
    end

    def summary(employee)
      status = if employee.joined_on > business_date
        "Upcoming"
      elsif employee.employed_on?(business_date)
        "Active"
      else
        "Former"
      end

      {
        number: employee.employee_number,
        name: employee.full_name,
        country: employee.country_code,
        department: employee.department.name,
        role: employee.job_role.name,
        status: status
      }
    end

    def details(employee)
      salaries = employee.salary_records.order(:effective_on).to_a
      last_effective = salaries.reverse_each.find { |salary| salary.status(on: business_date) == :effective }
      active = employee.employed_on?(business_date)
      current = last_effective if active
      previous = nil

      timeline = salaries.map do |salary|
        row = salary_data(salary).merge(
          status: timeline_status(salary, current),
          previous: salary_data(previous),
          change: salary_change(salary, previous)
        )
        previous = salary
        row
      end

      summary(employee).merge(
        joinedOn: employee.joined_on, lastWorkingOn: employee.last_working_on,
        current: salary_data(current), lastEffective: salary_data(last_effective), timeline: timeline.reverse,
        canRecordSalary: active && employee.id != current_account.employee_id,
        canRecordDeparture: employee.id != current_account.employee_id,
        asOf: business_date,
        currencies: SalaryRecord::CURRENCY_PRECISIONS
      )
    end

    def salary_data(salary)
      return unless salary

      { amount: salary.amount_minor.to_s, currency: salary.currency_code, effectiveOn: salary.effective_on }
    end

    def timeline_status(salary, current)
      return "Current" if salary == current

      case salary.status(on: business_date)
      when :scheduled then "Scheduled"
      when :unapplied then "Unapplied"
      else "Historical"
      end
    end

    def salary_change(salary, previous)
      change = salary.change_from(previous)
      return unless change

      { amount: change.fetch(:amount_minor).to_s, percentage: change.fetch(:percentage).to_f }
    end
  end
end
