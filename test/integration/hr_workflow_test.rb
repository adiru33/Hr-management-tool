require "test_helper"

class HrWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @department = Department.create!(name: "Engineering")
    @role = JobRole.create!(name: "Software Engineer")
    employee = create_employee("HR-01", "Amara Shah")
    @manager = HrAccount.create!(employee: employee, email: "amara@example.test", password: "sample-password")
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
    @manager.employee.update!(last_working_on: Date.current)
    sign_in

    travel 1.day do
      get api_session_path, as: :json
      assert_response :success
      assert_nil response.parsed_body.fetch("account")
    end
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
end
