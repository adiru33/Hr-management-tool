class CompensationOverview
  def initialize(as_of:, filters:)
    @as_of = as_of
    @filters = filters
  end

  def call
    rows = current_salaries.pluck("current_salaries.currency_code", "current_salaries.amount_minor")
    rows.group_by(&:first).sort_by(&:first).map do |currency, entries|
      amounts = entries.map(&:last).sort
      count = amounts.length
      # The two indices coincide for an odd count.
      median = Rational(amounts[(count - 1) / 2] + amounts[count / 2], 2)

      {
        currency: currency,
        headcount: count,
        meanMinor: Rational(amounts.sum, count).round.to_s,
        medianMinor: median.round.to_s
      }
    end
  end

  private

  def current_salaries
    # The composite employee/effective-date index supplies the latest eligible row for each employee.
    latest = SalaryRecord.where("salary_records.employee_id = employees.id")
      .where(effective_on: ..@as_of).order(effective_on: :desc).limit(1).select(:id)

    Employee.in_organization(**@filters).active_on(@as_of).joins(
      "INNER JOIN salary_records AS current_salaries ON current_salaries.id = (#{latest.to_sql})"
    )
  end
end
