require "test_helper"

class CompensationTest < ActiveSupport::TestCase
  setup do
    @department = Department.create!(name: "Engineering")
    @role = JobRole.create!(name: "Software Engineer")
    @manager = create_manager("HR-1", "first@example.test")
  end

  test "hire records the joining salary and its author" do
    employee = hire
    record = employee.salary_records.sole

    assert_equal Date.new(2020, 1, 1), record.effective_on
    assert_equal 100_000_000, record.amount_minor
    assert_equal "INR", record.currency_code
    assert_equal @manager, record.recorded_by_hr_account
    assert_equal "IN", employee.country_code
  end

  test "an invalid joining salary rolls back the employee" do
    assert_no_difference ["Employee.count", "SalaryRecord.count"] do
      assert_raises ActiveRecord::RecordInvalid do
        hire(amount_minor: 0)
      end
    end
  end

  test "current salary changes on the effective date and keeps each increase" do
    employee = hire
    starting = employee.salary_records.sole
    first = raise_salary(employee, 110_000_000, Date.new(2021, 1, 1))
    second = raise_salary(employee, 126_500_000, Date.new(2024, 1, 1))

    assert_equal :scheduled, second.status(on: Date.new(2023, 12, 31))
    assert_equal first, employee.current_salary(on: Date.new(2023, 12, 31))
    assert_equal second, employee.current_salary(on: Date.new(2024, 1, 1))
    assert_equal({ amount_minor: 10_000_000, percentage: 10 }, first.change_from(starting))
    assert_equal({ amount_minor: 16_500_000, percentage: 15 }, second.change_from(first))
  end

  test "a change in currency leaves increment figures blank" do
    employee = hire
    starting = employee.salary_records.sole
    changed = raise_salary(employee, 9_000_000, Date.new(2024, 1, 1), currency: "USD")

    assert_nil changed.change_from(starting)
  end

  test "resignation keeps history and marks entries after the last day unapplied" do
    employee = hire
    starting = employee.salary_records.sole
    planned = raise_salary(employee, 110_000_000, Date.new(2024, 6, 1))
    last_day = Date.new(2024, 5, 31)
    employee.update!(last_working_on: last_day)

    assert_includes Employee.active_on(last_day), employee
    assert_equal starting, employee.current_salary(on: last_day)
    assert_not_includes Employee.active_on(last_day + 1), employee
    assert_nil employee.current_salary(on: last_day + 1)
    assert_equal :unapplied, planned.reload.status(on: last_day + 1)
    assert_nil planned.change_from(starting)
    assert_equal 2, employee.salary_records.count
    assert_raises(ActiveRecord::RecordInvalid) { raise_salary(employee, 120_000_000, last_day + 1) }
  end

  test "employment dates govern HR access including the last working day" do
    employee = @manager.employee
    last_day = Date.new(2024, 5, 31)
    employee.update!(last_working_on: last_day)

    refute @manager.active_on?(employee.joined_on - 1)
    assert @manager.active_on?(last_day)
    refute @manager.active_on?(last_day + 1)
  end

  test "another HR manager can record a salary the employee cannot record themselves" do
    employee = @manager.employee
    date = employee.joined_on
    assert_raises(ActiveRecord::RecordInvalid) { raise_salary(employee, 100_000_000, date) }

    other = create_manager("HR-2", "second@example.test")
    record = raise_salary(employee, 100_000_000, date, author: other)
    assert_equal other, record.recorded_by_hr_account
  end

  test "SQLite rejects duplicate effective dates and invalid amounts" do
    employee = hire
    starting = employee.salary_records.sole
    row = starting.attributes.except("id")
    assert_raises(ActiveRecord::RecordNotUnique) { SalaryRecord.insert_all!([row]) }
    assert_raises(ActiveRecord::StatementInvalid) do
      SalaryRecord.insert_all!([row.merge("amount_minor" => 0, "effective_on" => starting.effective_on + 1)])
    end
  end

  test "recorded salary rows are read only" do
    record = hire.salary_records.sole
    assert_raises(ActiveRecord::ReadOnlyRecord) { record.update!(amount_minor: 1) }
  end

  test "amount conversion preserves currency precision" do
    assert_equal 1_234, SalaryRecord.minor_units_for("12.34", "INR")
    assert_equal 1_234, SalaryRecord.minor_units_for("1234", "JPY")
    assert_raises(ArgumentError) { SalaryRecord.minor_units_for("0", "INR") }
    assert_raises(ArgumentError) { SalaryRecord.minor_units_for("12.345", "INR") }
    assert_raises(ArgumentError) { SalaryRecord.minor_units_for("12.34", "JPY") }
  end

  test "invalid work country and employment dates are rejected" do
    employee = hire
    refute employee.update(country_code: "XX")
    assert employee.errors[:country_code].present?
    refute employee.update(last_working_on: employee.joined_on - 1)
    assert employee.errors[:last_working_on].present?
  end

  private

  def employee_attributes(number)
    {
      employee_number: number, full_name: "Demo Employee #{number}", country_code: "in",
      department: @department, job_role: @role, joined_on: Date.new(2020, 1, 1)
    }
  end

  def create_manager(number, email)
    employee = Employee.create!(employee_attributes(number))
    HrAccount.create!(employee: employee, email: email, password: "test-password-123",
      role: :hr_manager, access_enabled: true)
  end

  def hire(amount_minor: 100_000_000)
    Employee.hire!(
      attributes: employee_attributes("EMP-1"),
      salary: { amount_minor: amount_minor, currency_code: "inr" },
      recorded_by: @manager
    )
  end

  def raise_salary(employee, amount, date, currency: "INR", author: @manager)
    employee.salary_records.create!(
      amount_minor: amount, currency_code: currency, effective_on: date,
      recorded_by_hr_account: author
    )
  end
end
