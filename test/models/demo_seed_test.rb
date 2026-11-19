require "test_helper"
require_relative "../../db/demo_seed"

class DemoSeedTest < ActiveSupport::TestCase
  test "adds a raise for each completed anniversary through the demo date" do
    employee = Employee.new(id: 1, joined_on: Date.new(2018, 12, 20))
    rows = salary_rows(employee)

    assert_equal (2018..2025).map { |year| Date.new(year, 12, 20) }, rows.pluck(:effective_on)
    amounts = rows.pluck(:amount_minor)
    assert_equal [100_000_000, 110_000_000, 115_000_000, 120_000_000, 126_500_000], amounts.take(5)
    assert amounts.each_cons(2).all? { |previous, current| current > previous }
  end

  test "includes an anniversary on the last working day and stops afterward" do
    employee = Employee.new(
      id: 1, joined_on: Date.new(2018, 4, 25), last_working_on: Date.new(2020, 4, 25)
    )

    assert_equal (2018..2020).map { |year| Date.new(year, 4, 25) }, salary_rows(employee).pluck(:effective_on)
  end

  private

  def salary_rows(employee)
    DemoSeed.salary_rows(employee, currency: "INR", starting_amount: 100_000_000, author_id: 2)
  end
end
