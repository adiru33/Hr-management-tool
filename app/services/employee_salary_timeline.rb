class EmployeeSalaryTimeline
  Entry = Data.define(:salary, :previous, :status, :change) do
    def percentage_hundredths
      (change.fetch(:percentage) * 100).round if change
    end
  end

  attr_reader :current, :last_effective, :entries

  def initialize(employee, as_of:)
    salaries = employee.salary_records.order(:effective_on).to_a
    @last_effective = salaries.reverse_each.find { |salary| salary.status(on: as_of) == :effective }
    @current = @last_effective if employee.employed_on?(as_of)

    previous = nil
    @entries = salaries.map do |salary|
      entry = Entry.new(
        salary: salary, previous: previous, status: status_for(salary, as_of),
        change: salary.change_from(previous)
      )
      previous = salary
      entry
    end.reverse
  end

  private

  def status_for(salary, as_of)
    return "Current" if salary == current

    case salary.status(on: as_of)
    when :scheduled then "Scheduled"
    when :unapplied then "Unapplied"
    else "Historical"
    end
  end
end
