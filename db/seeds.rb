module DemoSeed
  EMPLOYEE_COUNT = 10_000
  BATCH_SIZE = 500
  DEPARTMENT_ROLES = {
    "Engineering" => ["Software Engineer", "Engineering Manager", "Data Analyst"],
    "Finance" => ["Financial Analyst", "Data Analyst"],
    "Operations" => ["Operations Specialist", "Data Analyst"],
    "People" => ["HR Manager", "HR Specialist"]
  }.freeze
  COUNTRY_COMPENSATION = {
    "IN" => ["INR", 100_000_000],
    "US" => ["USD", 9_000_000],
    "GB" => ["GBP", 5_500_000],
    "DE" => ["EUR", 6_300_000],
    "JP" => ["JPY", 6_500_000]
  }.freeze
  FIRST_NAMES = %w[Asha Noah Meera Luca Priya Hana Ravi Sofia Mina Omar].freeze
  LAST_NAMES = %w[Shah Miller Rao Weber Tanaka Reed Novak Patel Mori Wilson].freeze

  module_function

  def run
    passwords = manager_passwords

    ApplicationRecord.transaction do
      departments = DEPARTMENT_ROLES.keys.index_with { |name| Department.find_or_create_by!(name: name) }
      roles = DEPARTMENT_ROLES.values.flatten.uniq.index_with { |name| JobRole.find_or_create_by!(name: name) }
      managers = passwords.each_with_index.map do |password, index|
        employee = Employee.find_or_create_by!(employee_number: format("DEMO-HR-%02d", index + 1)) do |record|
          record.assign_attributes(
            full_name: ["Amara Shah", "Daniel Reed"].fetch(index), country_code: "US",
            department: departments.fetch("People"), job_role: roles.fetch("HR Manager"),
            joined_on: Date.new(2017, 1, 1)
          )
        end
        HrAccount.find_or_create_by!(employee: employee) do |account|
          account.email = "hr#{index + 1}@acme.example"
          account.password = password
        end
      end

      managers.each_with_index do |manager, index|
        add_salary_records([salary_row(manager.employee_id, "USD", 10_500_000, manager.employee.joined_on,
          managers.fetch(1 - index).id)])
      end

      (1..(EMPLOYEE_COUNT - managers.size)).each_slice(BATCH_SIZE) do |numbers|
        employees = numbers.map { |number| employee_row(number, departments, roles) }
        Employee.insert_all(employees, unique_by: :employee_number)
        employee_ids = Employee.where(employee_number: employees.pluck(:employee_number)).pluck(:employee_number, :id).to_h

        salaries = employees.each_with_index.flat_map do |employee, index|
          salary_rows(employee, employee_ids.fetch(employee[:employee_number]), numbers.fetch(index), managers)
        end
        add_salary_records(salaries)
      end
    end
  end

  def manager_passwords
    if Rails.env.development?
      return [
        ENV.fetch("ACME_DEMO_HR_ONE_PASSWORD", "local-acme-hr-one"),
        ENV.fetch("ACME_DEMO_HR_TWO_PASSWORD", "local-acme-hr-two")
      ]
    end

    [ENV.fetch("ACME_DEMO_HR_ONE_PASSWORD"), ENV.fetch("ACME_DEMO_HR_TWO_PASSWORD")]
  end

  def employee_row(number, departments, roles)
    country_index = (number - 1) % COUNTRY_COMPENSATION.size
    department_index = (number - 1) / COUNTRY_COMPENSATION.size
    department, job_roles = DEPARTMENT_ROLES.to_a.fetch(department_index % DEPARTMENT_ROLES.size)
    role = job_roles.fetch(department_index / DEPARTMENT_ROLES.size % job_roles.size)
    joined_on = Date.new(2018, 1, 1) + ((number - 1) % 730)

    {
      employee_number: format("DEMO-%05d", number),
      full_name: "#{FIRST_NAMES.fetch((number - 1) % FIRST_NAMES.size)} #{LAST_NAMES.fetch(department_index % LAST_NAMES.size)}",
      country_code: COUNTRY_COMPENSATION.keys.fetch(country_index),
      department_id: departments.fetch(department).id,
      job_role_id: roles.fetch(role).id,
      joined_on: joined_on,
      last_working_on: number.modulo(20).zero? ? joined_on.advance(years: 5) : nil
    }
  end

  def salary_rows(employee, employee_id, number, managers)
    currency, base = COUNTRY_COMPENSATION.fetch(employee.fetch(:country_code))
    starting_amount = base + (base * ((number - 1) % 31) / 100)
    joined_on = employee.fetch(:joined_on)
    [
      salary_row(employee_id, currency, starting_amount, joined_on, managers.first.id),
      salary_row(employee_id, currency, starting_amount * 110 / 100, joined_on.advance(years: 1), managers.first.id),
      salary_row(employee_id, currency, starting_amount * 1265 / 1000, joined_on.advance(years: 4), managers.last.id)
    ]
  end

  def salary_row(employee_id, currency, amount, date, author_id)
    {
      employee_id: employee_id, currency_code: currency, amount_minor: amount,
      effective_on: date, recorded_by_hr_account_id: author_id
    }
  end

  def add_salary_records(rows)
    SalaryRecord.insert_all(rows, unique_by: [:employee_id, :effective_on])
  end
end

DemoSeed.run if Rails.env.development? || ENV["ACME_SEED_DEMO"] == "1"
