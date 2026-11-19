require "test_helper"

class AccessManagementTest < ActionDispatch::IntegrationTest
  setup do
    @department = Department.create!(name: "People")
    @job_role = JobRole.create!(name: "People Operations")
    @admin = create_account("OPS-01", role: :access_admin)
    @manager = create_account("HR-01", role: :hr_manager)
    @replacement = create_account("EMP-01", role: :employee, enabled: false)
  end

  test "each role has access only to its workspace and management endpoints" do
    get api_access_accounts_path, as: :json
    assert_response :unauthorized

    sign_in(@manager)
    get api_access_accounts_path, as: :json
    assert_response :forbidden
    assert_equal ["wrong_role", "hr_manager"], response.parsed_body.values_at("code", "accountRole")
    patch api_access_account_path(@replacement), params: { operation: "grant" }, as: :json
    assert_response :forbidden

    sign_in(@admin)
    get api_access_accounts_path, as: :json
    assert_response :success
    accounts = response.parsed_body.fetch("accounts")
    assert_equal [@manager.id, @replacement.id].sort, accounts.pluck("id").sort
    assert accounts.none? { |account| account.key?("password_digest") || account.key?("salary") }

    get api_employees_path, as: :json
    assert_response :forbidden
    assert_equal ["wrong_role", "access_admin"], response.parsed_body.values_at("code", "accountRole")
    get api_compensation_path, as: :json
    assert_response :forbidden
    get salary_history_api_employee_path(@manager.employee.employee_number)
    assert_response :forbidden
    get api_employee_path(@manager.employee.employee_number), as: :json
    assert_response :forbidden
    post api_employee_salary_records_path(@manager.employee.employee_number), as: :json
    assert_response :forbidden
    patch api_access_account_path(@admin), params: { operation: "grant" }, as: :json
    assert_response :not_found
    assert_equal "access_admin", @admin.reload.role
  end

  test "replacing the sole HR manager preserves history and records the handover" do
    second_manager = create_account("HR-02", role: :hr_manager)
    saved_salary = @manager.employee.salary_records.create!(
      amount_minor: 100_000_000, currency_code: "INR", effective_on: @manager.employee.joined_on,
      recorded_by_hr_account: second_manager
    )
    second_manager.update!(access_enabled: false)

    old_manager = open_session
    sign_in(@manager, client: old_manager)
    sign_in(@replacement, expected: :unauthorized)
    sign_in(@admin)

    patch api_access_account_path(@manager),
      params: { operation: "record_departure", last_working_on: Date.current.iso8601 }, as: :json
    assert_response :success
    assert_equal "Active", response.parsed_body.fetch("status")
    assert_equal Date.current, @manager.employee.reload.last_working_on

    patch api_access_account_path(@manager), params: { operation: "revoke" }, as: :json
    assert_response :success
    assert_equal "Revoked", response.parsed_body.fetch("status")
    old_manager.get api_employees_path, as: :json
    assert_equal 401, old_manager.response.status

    patch api_access_account_path(@replacement), params: { operation: "grant" }, as: :json
    assert_response :success
    new_manager = open_session
    sign_in(@replacement, client: new_manager)
    new_manager.get api_employee_path(@manager.employee.employee_number), as: :json
    assert_equal 200, new_manager.response.status
    assert_equal saved_salary.amount_minor.to_s, new_manager.response.parsed_body.dig("timeline", 0, "amount")

    events = AccountAccessEvent.order(:id)
    assert_equal %w[record_departure revoke grant], events.pluck(:action)
    assert_equal [@admin.id], events.pluck(:actor_id).uniq
    assert_equal [@manager.id, @manager.id, @replacement.id], events.pluck(:target_id)
  end

  test "restoring access never restores a session that existed before revocation" do
    previous_session = open_session
    sign_in(@manager, client: previous_session)
    sign_in(@admin)

    %w[revoke grant].each do |operation|
      patch api_access_account_path(@manager), params: { operation: operation }, as: :json
      assert_response :success
    end

    previous_session.get api_employees_path, as: :json
    assert_equal 401, previous_session.response.status
    sign_in(@manager, client: previous_session)
    previous_session.get api_employees_path, as: :json
    assert_equal 200, previous_session.response.status
  end

  test "past departure disables access and an invalid action writes no audit event" do
    manager_session = open_session
    sign_in(@manager, client: manager_session)
    sign_in(@admin)

    patch api_access_account_path(@manager),
      params: { operation: "record_departure", last_working_on: Date.current.yesterday.iso8601 }, as: :json
    assert_response :success
    assert_equal "Inactive", response.parsed_body.fetch("status")
    manager_session.get api_employees_path, as: :json
    assert_equal 401, manager_session.response.status

    assert_no_difference "AccountAccessEvent.count" do
      patch api_access_account_path(@manager),
        params: { operation: "record_departure", last_working_on: "2026-02-30" }, as: :json
      assert_response :unprocessable_entity
    end
  end

  test "newly enrolled accounts have no HR access by default" do
    employee = Employee.create!(employee_number: "EMP-02", full_name: "Employee EMP-02",
      country_code: "IN", department: @department, job_role: @job_role, joined_on: Date.new(2020, 1, 1))
    account = HrAccount.create!(employee: employee, email: "emp-02@example.test", password: "local-test-password")

    assert account.role_employee?
    refute account.access_enabled?
    sign_in(account, expected: :unauthorized)
  end

  private

  def create_account(number, role:, enabled: true)
    employee = Employee.create!(employee_number: number, full_name: "Employee #{number}",
      country_code: "IN", department: @department, job_role: @job_role, joined_on: Date.new(2020, 1, 1))
    HrAccount.create!(employee: employee, email: "#{number.downcase}@example.test",
      password: "local-test-password", role: role, access_enabled: enabled)
  end

  def sign_in(account, client: self, expected: :success)
    client.post api_session_path, params: { email: account.email, password: "local-test-password" }, as: :json
    assert_equal(expected == :success ? 200 : 401, client.response.status)
  end
end
