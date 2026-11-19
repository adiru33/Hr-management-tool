require "csv"
require "set"

class EmployeeCsvImport
  class InvalidFile < StandardError; end

  HEADERS = EmployeeInput::HIRE_FIELDS.map(&:to_s).freeze
  MAX_ROWS = 10_000
  MAX_BYTES = 5 * 1024 * 1024
  ERROR_LIMIT = 100
  BATCH_SIZE = 500
  EMPLOYEE_COLUMNS = %w[employee_number full_name country_code department_id job_role_id joined_on].freeze

  def call(file, actor:)
    headers, rows = read_rows(file)
    onboarding = EmployeeInput.new
    existing = existing_employee_numbers(headers, rows)
    seen = Set.new
    errors = []
    hires = []

    rows.each do |row, number|
      begin
        raise InvalidFile, "Expected #{headers.length} columns." unless row.length == headers.length

        input = headers.zip(row).to_h
        employee_number = normalized_number(input.fetch(:employee_number))
        if employee_number.present? && !seen.add?(employee_number)
          raise InvalidFile, "That employee number appears more than once in the file."
        end
        if existing.include?(employee_number)
          raise InvalidFile, "Employee number has already been taken."
        end

        attributes, salary = onboarding.hiring_attributes(input)
        employee = Employee.new(attributes)
        unless employee.valid?(:csv_import)
          raise InvalidFile, employee.errors.full_messages.to_sentence
        end

        hires << [employee.attributes.slice(*EMPLOYEE_COLUMNS), salary]
      rescue EmployeeInput::InvalidInput, InvalidFile => error
        errors << { row: number, message: error.message }
      end
    end

    if errors.empty?
      save_hires(hires, actor)
      return { imported: hires.length }
    end

    {
      error: "No employees were imported. Fix the rows below and try again.",
      invalidRows: errors.length,
      rows: errors.first(ERROR_LIMIT)
    }
  rescue ActiveRecord::RecordNotUnique
    raise InvalidFile, "An employee number was added while the CSV was being checked. Review the file and try again."
  rescue ActiveRecord::InvalidForeignKey
    raise InvalidFile, "A required account, department, or job role changed. Review the file and try again."
  end

  private

  def existing_employee_numbers(headers, rows)
    column = headers.index(:employee_number)
    numbers = rows.map { |row, _| normalized_number(row[column]) }.reject(&:empty?).uniq
    numbers.each_slice(BATCH_SIZE).flat_map do |batch|
      Employee.where(employee_number: batch).pluck(:employee_number)
    end.to_set
  end

  def normalized_number(value)
    value.to_s.strip.upcase
  end

  def save_hires(hires, actor)
    Employee.transaction do
      actor.reload
      unless actor.role_hr_manager? && actor.sign_in_allowed_on?(Date.current)
        raise InvalidFile, "Your HR access changed while the file was being checked."
      end

      hires.each_slice(BATCH_SIZE) do |batch|
        inserted = Employee.insert_all!(batch.map(&:first), returning: %w[employee_number id])
        employee_ids = inserted.rows.to_h
        salaries = batch.map do |employee, salary|
          salary.merge(employee_id: employee_ids.fetch(employee.fetch("employee_number")),
            effective_on: employee.fetch("joined_on"), recorded_by_hr_account_id: actor.id)
        end
        SalaryRecord.insert_all!(salaries)
      end
    end
  end

  def read_rows(file)
    raise InvalidFile, "Choose a CSV file to upload." unless file.is_a?(ActionDispatch::Http::UploadedFile)

    content = file.read(MAX_BYTES + 1).to_s.force_encoding(Encoding::UTF_8)
    raise InvalidFile, "The CSV file must be 5 MB or smaller." if content.bytesize > MAX_BYTES
    raise InvalidFile, "Save the CSV with UTF-8 encoding and try again." unless content.valid_encoding?

    records = CSV.new(content.delete_prefix("\uFEFF"))
    headers = records.shift
    unless headers&.map(&:to_s)&.sort == HEADERS.sort
      raise InvalidFile, "Use these CSV headers: #{HEADERS.join(', ')}."
    end

    rows = []
    records.each_with_index do |row, index|
      next if row.all? { |column| column.to_s.strip.empty? }

      raise InvalidFile, "A CSV upload can contain at most #{MAX_ROWS} employees." if rows.length == MAX_ROWS

      rows << [row, index + 2]
    end
    raise InvalidFile, "The CSV has no employee rows." if rows.empty?

    [headers.map(&:to_sym), rows]
  rescue CSV::MalformedCSVError
    raise InvalidFile, "The file is not a well-formed CSV. Check the commas and quotation marks."
  end
end
