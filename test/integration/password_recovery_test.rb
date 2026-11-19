require "test_helper"

class PasswordRecoveryTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  OLD_PASSWORD = "local-test-password"
  NEW_PASSWORD = "new-test-password-2026"

  setup do
    @department = Department.create!(name: "People")
    @role = JobRole.create!(name: "People Operations")
    @manager = create_account("HR-01", :hr_manager)
    @admin = create_account("OPS-01", :access_admin)
    ActionMailer::Base.deliveries.clear
  end

  teardown { ActionMailer::Base.deliveries.clear }

  test "HR and Access Admin can reset their passwords without restoring existing sessions" do
    [@manager, @admin].each do |account|
      old_session = open_session
      sign_in(account, OLD_PASSWORD, client: old_session)
      assert_equal 200, old_session.response.status

      token = request_token(account)
      assert_not_equal token, account.reload.reset_password_token
      version = account.access_version
      reset(token, NEW_PASSWORD)
      assert_response :success
      assert_equal version + 1, account.reload.access_version
      assert_nil account.reset_password_token

      old_session.get api_session_path, as: :json
      assert_nil old_session.response.parsed_body.fetch("account")
      sign_in(account, OLD_PASSWORD)
      assert_response :unauthorized
      sign_in(account, NEW_PASSWORD)
      assert_response :success
      assert_equal account.role, response.parsed_body.dig("account", "role")

      reset(token, NEW_PASSWORD)
      assert_response :unprocessable_entity
    end
  end

  test "unknown emails and inactive accounts get the same response as eligible accounts" do
    request_token(@manager)
    expected = response.parsed_body.fetch("message")
    @manager.update!(access_enabled: false)

    [@manager.email, "unknown@example.test"].each do |email|
      assert_no_difference -> { ActionMailer::Base.deliveries.size } do
        perform_enqueued_jobs { post api_password_reset_path, params: { email: email }, as: :json }
      end
      assert_response :accepted
      assert_equal expected, response.parsed_body.fetch("message")
    end
  end

  test "a link issued before access was revoked cannot reset that account" do
    token = request_token(@manager)
    @manager.update!(access_enabled: false)

    reset(token, NEW_PASSWORD)
    assert_response :unprocessable_entity
    refute @manager.reload.access_enabled?
    assert @manager.valid_password?(OLD_PASSWORD)
    assert_nil @manager.reset_password_token

    @manager.update!(access_enabled: true)
    reset(token, NEW_PASSWORD)
    assert_response :unprocessable_entity
  end

  test "expired reset links and invalid passwords are rejected" do
    token = request_token(@manager)
    reset(token, "too-short")
    assert_response :unprocessable_entity
    assert_match(/at least 12 characters/, response.parsed_body.fetch("error"))
    assert @manager.reload.valid_password?(OLD_PASSWORD)

    travel 31.minutes do
      reset(token, NEW_PASSWORD)
      assert_response :unprocessable_entity
      assert_match(/invalid or expired/, response.parsed_body.fetch("error"))
    end
  end

  test "the React password reset page does not cache or refer its link" do
    get password_reset_path, params: { token: "sample-link-token" }
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_select "div#app"
  end

  private

  def create_account(number, role)
    employee = Employee.create!(employee_number: number, full_name: "Employee #{number}",
      country_code: "IN", department: @department, job_role: @role, joined_on: Date.new(2020, 1, 1))
    HrAccount.create!(employee: employee, email: "#{number.downcase}@example.test", password: OLD_PASSWORD,
      role: role, access_enabled: true)
  end

  def request_token(account)
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      perform_enqueued_jobs do
        post api_password_reset_path, params: { email: " #{account.email.upcase} " }, as: :json
      end
    end
    assert_response :accepted
    mail = ActionMailer::Base.deliveries.last
    assert_equal [account.email], mail.to
    assert_equal ["account-recovery@acme.example"], mail.from
    link = URI.parse(mail.body.decoded.lines.find { |line| line.start_with?("http") }.strip)
    assert_equal "www.example.com", link.host
    assert_equal password_reset_path, link.path
    URI.decode_www_form(link.query).to_h.fetch("token")
  end

  def sign_in(account, password, client: self)
    client.post api_session_path, params: { email: account.email, password: password }, as: :json
  end

  def reset(token, password)
    patch api_password_reset_path, params: { token: token, password: password, password_confirmation: password }, as: :json
  end
end
