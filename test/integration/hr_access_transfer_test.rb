require "test_helper"

class HrAccessTransferTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  MAILBOX = "hr@example.test"
  OLD_PASSWORD = "original-password"
  TEMPORARY_PASSWORD = "temporary-harry-password"
  NEW_PASSWORD = "harrys-private-password"

  setup do
    @department = Department.create!(name: "People")
    @job_role = JobRole.create!(name: "People Operations")
    @alex = HrAccount.create!(employee: employee("HR-01", "Alex"), role: :hr_manager,
      email: MAILBOX, password: OLD_PASSWORD, access_enabled: true)
    @admin = HrAccount.create!(employee: employee("OPS-01", "Admin"), role: :access_admin,
      email: "admin@example.test", password: OLD_PASSWORD, access_enabled: true)
    @harry = employee("HR-02", "Harry")
    @colleague = employee("EMP-03", "Colleague")
    @salary = @colleague.salary_records.create!(amount_minor: 4_000_000, currency_code: "USD",
      effective_on: @colleague.joined_on, recorded_by_hr_account: @alex)
    ActionMailer::Base.deliveries.clear
  end

  teardown { ActionMailer::Base.deliveries.clear }

  test "the mailbox changes hands while existing salary records and their author are preserved" do
    old_session = open_session
    sign_in(old_session, MAILBOX, OLD_PASSWORD)
    assert_equal 200, old_session.response.status
    sign_in(self, @admin.email, OLD_PASSWORD)

    get transfer_candidate_api_access_account_path(@alex), params: { employee_number: "hr-02" }, as: :json
    assert_response :success
    assert_equal({ "number" => "HR-02", "name" => "Harry" }, response.parsed_body)

    assert_difference "HrAccount.count", 1 do
      transfer
      assert_response :success
    end
    assert_equal ["Harry", MAILBOX, "Password setup required"], response.parsed_body.values_at("name", "email", "status")
    incoming = @harry.reload.hr_account
    assert_nil @alex.reload.email
    refute @alex.access_enabled?
    assert_equal @salary.recorded_by_hr_account_id, @alex.id
    assert_equal [@admin, @alex, incoming], AccountAccessEvent.find_by!(action: "transfer")
      .then { |event| [event.actor, event.outgoing_account, event.target] }

    old_session.get api_employees_path, as: :json
    assert_equal 401, old_session.response.status
    sign_in(old_session, MAILBOX, OLD_PASSWORD)
    assert_equal 401, old_session.response.status

    harry_session = open_session
    duplicate_session = open_session
    [harry_session, duplicate_session].each do |client|
      sign_in(client, MAILBOX, TEMPORARY_PASSWORD)
      assert_equal 200, client.response.status
      assert client.response.parsed_body.dig("account", "passwordChangeRequired")
      client.get api_employees_path, as: :json
      assert_equal 403, client.response.status
      assert_equal "password_change_required", client.response.parsed_body.fetch("code")
    end
    change_password(harry_session, TEMPORARY_PASSWORD)
    assert_equal 422, harry_session.response.status
    change_password(harry_session, NEW_PASSWORD)
    assert_equal 200, harry_session.response.status
    refute harry_session.response.parsed_body.dig("account", "passwordChangeRequired")

    assert_equal @alex.id, @salary.reload.recorded_by_hr_account_id
    harry_session.get api_employee_path(@colleague.employee_number), as: :json
    assert_equal 200, harry_session.response.status
    assert_equal "Alex", harry_session.response.parsed_body.dig("timeline", 0, "recordedBy")
    duplicate_session.get api_employees_path, as: :json
    assert_equal 401, duplicate_session.response.status
    sign_in(duplicate_session, MAILBOX, TEMPORARY_PASSWORD)
    assert_equal 401, duplicate_session.response.status
    sign_in(duplicate_session, MAILBOX, NEW_PASSWORD)
    assert_equal 200, duplicate_session.response.status
  end

  test "only admins can transfer to eligible employees and rejected transfers preserve the mailbox" do
    sign_in(self, MAILBOX, OLD_PASSWORD)
    transfer
    assert_response :forbidden

    sign_in(self, @admin.email, OLD_PASSWORD)
    former = employee("FORMER-01", "Former HR", last_working_on: Date.current.yesterday)
    [@alex.employee, @admin.employee, former].each do |candidate|
      transfer(candidate: candidate)
      assert_response :unprocessable_entity
    end
    transfer(password: OLD_PASSWORD)
    assert_response :unprocessable_entity
    transfer(password: "short")
    assert_response :unprocessable_entity
    assert_equal MAILBOX, @alex.reload.email
    assert @alex.access_enabled?
    assert_nil @harry.reload.hr_account
    assert_empty AccountAccessEvent.all
  end

  test "handover clears issued and queued recovery requests for the old mailbox owner" do
    perform_enqueued_jobs do
      post api_password_reset_path, params: { email: MAILBOX }, as: :json
    end
    assert_response :accepted
    mail = ActionMailer::Base.deliveries.last
    link = URI.parse(mail.body.decoded.lines.find { |line| line.start_with?("http") }.strip)
    old_token = URI.decode_www_form(link.query).to_h.fetch("token")
    post api_password_reset_path, params: { email: MAILBOX }, as: :json
    assert_enqueued_jobs 1

    sign_in(self, @admin.email, OLD_PASSWORD)
    existing_account = HrAccount.create!(employee: @harry, email: "harry@example.test", password: OLD_PASSWORD)
    transfer
    assert_response :success
    assert_equal existing_account.id, @harry.reload.hr_account.id
    assert_nil @alex.reload.reset_password_token
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      perform_enqueued_jobs
    end
    patch api_password_reset_path, params: { token: old_token, password: NEW_PASSWORD,
      password_confirmation: NEW_PASSWORD }, as: :json
    assert_response :unprocessable_entity
    patch api_access_account_path(@alex), params: { operation: "grant" }, as: :json
    assert_response :unprocessable_entity

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      perform_enqueued_jobs { post api_password_reset_path, params: { email: MAILBOX }, as: :json }
    end
    new_link = URI.parse(ActionMailer::Base.deliveries.last.body.decoded.lines.find { |line| line.start_with?("http") }.strip)
    new_token = URI.decode_www_form(new_link.query).to_h.fetch("token")
    patch api_password_reset_path, params: { token: new_token, password: NEW_PASSWORD,
      password_confirmation: NEW_PASSWORD }, as: :json
    assert_response :success
    sign_in(self, MAILBOX, NEW_PASSWORD)
    assert_response :success
    assert_equal ["Harry", false], response.parsed_body.fetch("account").values_at("name", "passwordChangeRequired")
  end

  private

  def employee(number, name, last_working_on: nil)
    Employee.create!(employee_number: number, full_name: name, department: @department, job_role: @job_role,
      country_code: "US", joined_on: Date.new(2020, 1, 1), last_working_on: last_working_on)
  end

  def sign_in(client, email, password)
    client.post api_session_path, params: { email: email, password: password }, as: :json
  end

  def change_password(client, password)
    client.patch api_session_path, params: { password: password, password_confirmation: password }, as: :json
  end

  def transfer(candidate: @harry, password: TEMPORARY_PASSWORD)
    patch api_access_account_path(@alex), params: { operation: "transfer", employee_number: candidate.employee_number,
      password: password, password_confirmation: password }, as: :json
  end
end
