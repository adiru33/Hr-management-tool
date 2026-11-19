require "test_helper"

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

  private

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
