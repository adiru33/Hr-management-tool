require "test_helper"
require "tempfile"

class HrWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @department = Department.create!(name: "Engineering")
    @role = JobRole.create!(name: "Software Engineer")
    employee = create_employee("HR-01", "Amara Shah")
    @manager = HrAccount.create!(employee: employee, email: "amara@example.test", password: "sample-password",
      role: :hr_manager, access_enabled: true)
  end

  test "sign-in establishes a session and sign-out clears it" do
    get api_session_path, as: :json
    assert_response :success
    assert_nil response.parsed_body.fetch("account")

    sign_in(email: " AMARA@example.test ")
    assert_equal "Amara Shah", response.parsed_body.dig("account", "name")
    assert response.parsed_body.fetch("csrfToken").present?

    get api_session_path, as: :json
    assert_equal "Amara Shah", response.parsed_body.dig("account", "name")
    assert_equal "no-store", response.headers["Cache-Control"]

    delete api_session_path, as: :json
    assert_response :success
    get api_session_path, as: :json
    assert_nil response.parsed_body.fetch("account")
  end

  test "invalid credentials and inactive HR accounts cannot sign in" do
    post api_session_path, params: { email: @manager.email, password: "incorrect" }, as: :json
    assert_response :unauthorized
    invalid_error = response.parsed_body.fetch("error")

    @manager.employee.update!(last_working_on: Date.current.yesterday)
    post api_session_path, params: { email: @manager.email, password: "sample-password" }, as: :json
    assert_response :unauthorized
    assert_equal invalid_error, response.parsed_body.fetch("error")
  end

  test "retains access on the last working day and ends an existing session afterward" do
    travel_to Time.zone.local(2026, 11, 19, 23, 59)
    @manager.employee.update!(last_working_on: Date.current)
    sign_in

    travel 2.minutes
    get api_session_path, as: :json
    assert_response :success
    assert_nil response.parsed_body.fetch("account")
  ensure
    travel_back
  end

  test "Rails rejects a sign-in request without a valid CSRF token" do
    ApplicationController.allow_forgery_protection = true
    post api_session_path, params: { email: @manager.email, password: "sample-password" }, as: :json
    assert_response :unprocessable_entity

    get api_session_path, as: :json
    token = response.parsed_body.fetch("csrfToken")
    post api_session_path, params: { email: @manager.email, password: "sample-password" },
      headers: { "X-CSRF-Token" => token }, as: :json
    assert_response :success
    authenticated_token = response.parsed_body.fetch("csrfToken")

    delete api_session_path, headers: { "X-CSRF-Token" => token }, as: :json
    assert_response :unprocessable_entity
    delete api_session_path, headers: { "X-CSRF-Token" => authenticated_token }, as: :json
    assert_response :success
  ensure
    ApplicationController.allow_forgery_protection = false
  end

  test "employee records require an active HR session" do
    get api_employees_path, as: :json
    assert_response :unauthorized
    get api_employee_path("HR-01"), as: :json
    assert_response :unauthorized

    sign_in
    @manager.employee.update!(last_working_on: Date.current.yesterday)
    get api_employee_path("HR-01"), as: :json
    assert_response :unauthorized
  end

  test "matches employee numbers and names and combines directory filters" do
    target = create_employee("EMP-001", "Asha Shah")
    create_employee("EMP-002", "Asha Rao", country_code: "US")
    create_employee("EMP-003", "Former Shah", last_working_on: Date.current.yesterday)
    sign_in

    get api_employees_path, params: { search: "emp-001" }, as: :json
    assert_response :success
    assert_equal [target.employee_number], response.parsed_body.fetch("employees").pluck("number")

    get api_employees_path, params: {
      search: "shah", country: "IN", department: @department.name, role: @role.name, status: "Active"
    }, as: :json
    assert_equal [target.employee_number, @manager.employee.employee_number].sort,
      response.parsed_body.fetch("employees").pluck("number").sort

    get api_employees_path, params: { search: "%" }, as: :json
    assert_equal 0, response.parsed_body.fetch("total")
  end

  test "employee directory returns a stable page and the overall count" do
    25.times { |index| create_employee("EMP-#{index}", "Demo Employee") }
    sign_in

    get api_employees_path, as: :json
    assert_response :success
    first_page = response.parsed_body
    assert_equal 26, first_page.fetch("total")
    assert_equal 25, first_page.fetch("employees").length

    get api_employees_path, params: { page: 2 }, as: :json
    second_page = response.parsed_body
    assert_equal 2, second_page.fetch("page")
    assert_equal ["EMP-24"], second_page.fetch("employees").pluck("number")
  end

  test "employee detail includes current, previous, and scheduled salary information" do
    target = create_employee("EMP-001", "Asha Shah")
    record_salary(target, amount: 100_000_000, on: target.joined_on)
    record_salary(target, amount: 110_000_000, on: Date.current)
    record_salary(target, amount: 120_000_000, on: Date.current.tomorrow)
    sign_in

    get api_employee_path(target.employee_number), as: :json
    assert_response :success
    detail = response.parsed_body
    assert_equal "110000000", detail.dig("current", "amount")
    assert_equal ["Scheduled", "Current", "Historical"], detail.fetch("timeline").pluck("status")
    assert_equal "100000000", detail.dig("timeline", 1, "previous", "amount")
    assert_equal({ "amount" => "10000000", "percentage" => 10 }, detail.dig("timeline", 1, "change"))
    assert detail.fetch("canRecordSalary")

    get api_employee_path(@manager.employee.employee_number), as: :json
    refute response.parsed_body.fetch("canRecordSalary")
  end

  test "saving a future salary persists it with its author and leaves today's salary unchanged" do
    target = create_employee("EMP-001", "Asha Shah")
    record_salary(target, amount: 100_000_000, on: target.joined_on)
    tomorrow = Date.current.tomorrow
    sign_in

    assert_difference "SalaryRecord.count", 1 do
      add_salary(target, amount: "1100000.50", date: tomorrow.iso8601)
      assert_response :created
    end
    detail = response.parsed_body
    assert_equal "100000000", detail.dig("current", "amount")
    assert_equal "Scheduled", detail.dig("timeline", 0, "status")
    assert_equal @manager.id, target.salary_records.find_by!(effective_on: tomorrow).recorded_by_hr_account_id

    get api_employee_path(target.employee_number), as: :json
    assert_equal "110000050", response.parsed_body.dig("timeline", 0, "amount")
    travel_to tomorrow do
      sign_in
      get api_employee_path(target.employee_number), as: :json
      assert_response :success
      assert_equal "110000050", response.parsed_body.dig("current", "amount")
      assert_equal "Current", response.parsed_body.dig("timeline", 0, "status")
    end
  end

  test "salary creation requires HR access and blocks self edits" do
    target = @manager.employee
    assert_no_difference "SalaryRecord.count" do
      add_salary(target, amount: "1500000", date: Date.current.iso8601)
      assert_response :unauthorized

      sign_in
      add_salary(target, amount: "1500000", date: Date.current.iso8601)
      assert_response :unprocessable_entity
      assert_match(/cannot change their own salary/, response.parsed_body.fetch("error"))
    end
  end

  test "salary creation rejects duplicate dates, invalid amounts, and invalid dates" do
    target = create_employee("EMP-001", "Asha Shah", last_working_on: Date.current.tomorrow)
    record_salary(target, amount: 100_000_000, on: target.joined_on)
    sign_in

    assert_no_difference "SalaryRecord.count" do
      cases = [
        ["1200000", target.joined_on.iso8601, /already has a salary record/],
        ["1200000.005", Date.current.iso8601, /at most 2 decimal places/],
        ["1200000", "2026-02-30", /valid effective date/],
        ["1200000", (target.last_working_on + 1).iso8601, /employment dates/]
      ]
      cases.each do |amount, date, message|
        add_salary(target, amount: amount, date: date)
        assert_response :unprocessable_entity
        assert_match(message, response.parsed_body.fetch("error"))
      end
    end
  end

  test "HR can create a profile and starting salary together" do
    sign_in
    assert_difference("Employee.count", 1) do
      assert_difference("SalaryRecord.count", 1) do
        post api_employees_path, params: hire_input, as: :json
        assert_response :created
      end
    end
    employee = Employee.find_by!(employee_number: "NEW.001")
    salary = employee.salary_records.sole
    assert_equal employee.joined_on, salary.effective_on
    assert_equal 110_000_050, salary.amount_minor
    assert_equal @manager, salary.recorded_by_hr_account

    add_salary(employee, amount: "1200000", date: Date.current.tomorrow.iso8601)
    assert_response :created
  end

  test "invalid hiring details create neither an employee nor a salary" do
    sign_in
    assert_no_difference ["Employee.count", "SalaryRecord.count"] do
      [{ annual_salary: "120.003" }, { department: "Unknown" }, { joined_on: "2026-02-30" }].each do |overrides|
        post api_employees_path, params: hire_input.merge(overrides), as: :json
        assert_response :unprocessable_entity
      end
    end
  end

  test "editing a profile leaves its identifier, joined date, and salary history intact" do
    target = create_employee("EMP-001", "Asha Shah")
    starting = record_salary(target, amount: 100_000_000, on: target.joined_on)
    sign_in

    patch api_employee_path(target.employee_number), params: hire_input.merge(full_name: "Asha Rao", country_code: "GB"),
      as: :json
    assert_response :success
    assert_equal "Asha Rao", target.reload.full_name
    assert_equal "GB", target.country_code
    assert_equal "EMP-001", target.employee_number
    assert_equal starting.effective_on, target.joined_on
    assert_equal [starting.id], target.salary_records.ids
  end

  test "recording departure retains history and excludes future salaries" do
    target = create_employee("EMP-001", "Asha Shah")
    record_salary(target, amount: 100_000_000, on: target.joined_on)
    record_salary(target, amount: 120_000_000, on: Date.current.tomorrow)
    sign_in

    patch departure_api_employee_path(target.employee_number), params: { last_working_on: Date.current.yesterday.iso8601 },
      as: :json
    assert_response :success
    detail = response.parsed_body
    assert_equal "Former", detail.fetch("status")
    assert_nil detail.fetch("current")
    assert_equal ["Unapplied", "Historical"], detail.fetch("timeline").pluck("status")
    assert_equal 2, target.salary_records.count

    patch departure_api_employee_path(@manager.employee.employee_number), params: { last_working_on: Date.current.iso8601 },
      as: :json
    assert_response :forbidden
  end

  test "CSV import creates employees and joining salaries with the signed-in HR author" do
    sign_in
    csv = <<~CSV
      #{csv_headers}
      CSV-001,"Mehra, Asha",IN,Engineering,Software Engineer,2026-10-01,1200000.50,INR
      CSV-002,Hana Watanabe,JP,Engineering,Software Engineer,2026-10-02,6000000,JPY
    CSV

    assert_difference "Employee.count", 2 do
      assert_difference "SalaryRecord.count", 2 do
        upload_csv("\uFEFF" + csv)
        assert_response :created
      end
    end
    assert_equal 2, response.parsed_body.fetch("imported")
    employee = Employee.find_by!(employee_number: "CSV-001")
    salary = employee.salary_records.sole
    assert_equal "Mehra, Asha", employee.full_name
    assert_equal employee.joined_on, salary.effective_on
    assert_equal 120_000_050, salary.amount_minor
    assert_equal @manager, salary.recorded_by_hr_account
  end

  test "CSV import reports row errors and rolls back the whole file" do
    existing = create_employee("EXISTS-1", "Existing employee")
    sign_in
    csv = <<~CSV
      #{csv_headers}
      CSV-001,Asha Shah,IN,Engineering,Software Engineer,2026-10-01,1200000,INR
      exists-1,An existing number,IN,Engineering,Software Engineer,2026-10-01,1200000,INR
      csv-001,A duplicate in the file,IN,Engineering,Software Engineer,2026-10-01,1200000,INR
      CSV-003,Invalid amount,JP,Engineering,Software Engineer,2026-10-01,6500000.50,JPY
      CSV-004,Unknown job role,IN,Engineering,Unknown,2026-10-01,1200000,INR
    CSV

    assert_no_difference ["Employee.count", "SalaryRecord.count"] do
      upload_csv(csv)
      assert_response :unprocessable_entity
    end
    errors = response.parsed_body.fetch("rows")
    assert_equal [3, 4, 5, 6], errors.pluck("row")
    assert_match(/already been taken/, errors[0].fetch("message"))
    assert_match(/more than once/, errors[1].fetch("message"))
    assert_match(/0 decimal places/, errors[2].fetch("message"))
    assert_match(/existing job role/, errors[3].fetch("message"))
    assert_equal "Existing employee", existing.reload.full_name
  end

  test "CSV upload rejects missing columns, malformed input, and unauthorized requests" do
    upload_csv("#{csv_headers}\n")
    assert_response :unauthorized

    sign_in
    upload_csv("employee_number,country_code\nNEW,IN\n")
    assert_response :unprocessable_entity
    assert_match(/CSV headers/, response.parsed_body.fetch("error"))

    upload_csv("#{csv_headers}\nNEW,\"Unclosed name\n")
    assert_response :unprocessable_entity
    assert_match(/well-formed CSV/, response.parsed_body.fetch("error"))
  end

  test "CSV uploads over the row limit fail before creating records" do
    sign_in
    row = "BULK-001,Asha Shah,IN,Engineering,Software Engineer,2026-10-01,1200000,INR\n"

    assert_no_difference ["Employee.count", "SalaryRecord.count"] do
      upload_csv("#{csv_headers}\n" + row * (EmployeeCsvImport::MAX_ROWS + 1))
      assert_response :unprocessable_entity
    end
    assert_match(/at most 10000 employees/, response.parsed_body.fetch("error"))
  end

  private

  def hire_input
    {
      employee_number: "NEW.001", full_name: "Asha New", country_code: "IN",
      department: @department.name, job_role: @role.name, joined_on: Date.current.iso8601,
      annual_salary: "1100000.50", currency: "INR"
    }
  end

  def csv_headers
    "employee_number,full_name,country_code,department,job_role,joined_on,annual_salary,currency"
  end

  def upload_csv(content)
    Tempfile.create(["employee-import", ".csv"]) do |file|
      file.write(content)
      file.flush
      upload = Rack::Test::UploadedFile.new(file.path, "text/csv")
      post import_api_employees_path, params: { file: upload }
    end
  end

  def create_employee(number, name, **overrides)
    Employee.create!({
      employee_number: number, full_name: name, country_code: "IN",
      department: @department, job_role: @role, joined_on: Date.new(2020, 1, 1)
    }.merge(overrides))
  end

  def sign_in(email: @manager.email)
    post api_session_path, params: { email: email, password: "sample-password" }, as: :json
    assert_response :success
  end

  def record_salary(employee, amount:, on:)
    employee.salary_records.create!(
      amount_minor: amount, currency_code: "INR", effective_on: on, recorded_by_hr_account: @manager
    )
  end

  def add_salary(employee, amount:, date:)
    post api_employee_salary_records_path(employee.employee_number),
      params: { amount: amount, currency: "INR", effective_on: date }, as: :json
  end
end
