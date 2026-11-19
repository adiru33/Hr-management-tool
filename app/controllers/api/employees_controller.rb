module Api
  class EmployeesController < BaseController
    PAGE_SIZE = 25

    before_action :require_hr_account

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
        filters: {
          countries: Employee::COUNTRY_CODES,
          departments: Department.order(:name).pluck(:name),
          roles: JobRole.order(:name).pluck(:name),
          statuses: %w[Active Former Upcoming]
        }
      }
    end

    def show
      render json: details(find_employee)
    end

    private

    def filtered_employees
      filters = params.permit(:search, :country, :department, :role, :status)
      employees = Employee.all
      search = filters[:search].to_s.strip.first(100)

      if search.present?
        pattern = "%#{Employee.sanitize_sql_like(search, "!")}%"
        employees = employees.where(
          "full_name LIKE :pattern ESCAPE '!' OR employee_number LIKE :pattern ESCAPE '!'", pattern: pattern
        )
      end
      employees = employees.where(country_code: filters[:country]) if filters[:country].present?
      if filters[:department].present?
        employees = employees.where(department: Department.where(name: filters[:department]))
      end
      employees = employees.where(job_role: JobRole.where(name: filters[:role])) if filters[:role].present?

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
        canRecordSalary: active && employee.id != current_hr_account.employee_id,
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
