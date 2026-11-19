module DemoSeed
  EMPLOYEE_COUNT = 10_000
  BATCH_SIZE = 500
  SALARY_HISTORY_THROUGH = Date.new(2026, 11, 19)
  # Retain the original first- and fourth-year amounts in the demo history.
  EARLY_SALARY_MULTIPLIERS = [1000, 1100, 1150, 1200, 1265].freeze
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
          account.role = :hr_manager
          account.access_enabled = true
        end
      end

      managers.each_with_index do |manager, index|
        add_salary_records(salary_rows(manager.employee, currency: "USD", starting_amount: 10_500_000,
          author_id: managers.fetch(1 - index).id))
      end

      (1..(EMPLOYEE_COUNT - managers.size)).each_slice(BATCH_SIZE) do |numbers|
        rows = numbers.map { |number| employee_row(number, departments, roles) }
        Employee.insert_all(rows, unique_by: :employee_number)
        employees = Employee.where(employee_number: rows.pluck(:employee_number)).index_by(&:employee_number)

        salaries = rows.zip(numbers).flat_map do |row, number|
          employee = employees.fetch(row.fetch(:employee_number))
          currency, base = COUNTRY_COMPENSATION.fetch(employee.country_code)
          starting_amount = base + (base * ((number - 1) % 31) / 100)
          salary_rows(employee, currency: currency, starting_amount: starting_amount, author_id: managers.first.id)
        end
        add_salary_records(salaries)
      end

      seed_access_accounts
    end
  end

  def seed_access_accounts
    accounts = [
      ["DEMO-00019", "access-admin@acme.example", :access_admin, "ACME_DEMO_ADMIN_ONE_PASSWORD", "local-acme-access-one"],
      ["DEMO-00021", "backup-admin@acme.example", :access_admin, "ACME_DEMO_ADMIN_TWO_PASSWORD", "local-acme-access-two"],
      ["DEMO-00022", "replacement.hr@acme.example", :employee, "ACME_DEMO_REPLACEMENT_PASSWORD", "local-acme-replacement"]
    ]
    accounts.each do |number, email, role, variable, default|
      employee = Employee.find_by!(employee_number: number)
      HrAccount.find_or_create_by!(employee: employee) do |account|
        account.email = email
        account.role = role
        account.access_enabled = role == :access_admin
        account.password = Rails.env.development? ? ENV.fetch(variable, default) : ENV.fetch(variable)
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

  def salary_rows(employee, currency:, starting_amount:, author_id:)
    last_date = [SALARY_HISTORY_THROUGH, employee.last_working_on].compact.min
    joined_on = employee.joined_on
    amount = starting_amount
    rows = []

    (0..(last_date.year - joined_on.year)).each do |year|
      date = joined_on.advance(years: year)
      break if date > last_date

      multiplier = EARLY_SALARY_MULTIPLIERS[year]
      amount = multiplier ? starting_amount * multiplier / 1000 : amount * 105 / 100
      rows << {
        employee_id: employee.id, currency_code: currency, amount_minor: amount,
        effective_on: date, recorded_by_hr_account_id: author_id
      }
    end

    rows
  end

  def add_salary_records(rows)
    SalaryRecord.insert_all(rows, unique_by: [:employee_id, :effective_on])
  end
end
