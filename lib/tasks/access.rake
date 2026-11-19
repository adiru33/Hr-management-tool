require "io/console"

namespace :access do
  desc "Enroll a verified employee or Access Admin account"
  task :enroll, [:employee_number, :email, :role] => :environment do |_task, args|
    role = args[:role] || "employee"
    unless args[:employee_number].present? && args[:email].present? && %w[employee access_admin].include?(role)
      abort "Usage: bin/rails 'access:enroll[EMPLOYEE_NUMBER,WORK_EMAIL,employee|access_admin]'"
    end

    employee = Employee.find_by!(employee_number: args[:employee_number])
    abort "This employee already has an enrolled account." if employee.hr_account
    console = IO.console or abort "Run this task in an interactive terminal."
    password = console.getpass("Password: ")
    unless password&.bytesize&.between?(12, 72) && password == console.getpass("Confirm password: ")
      abort "Passwords must match and contain 12 to 72 bytes."
    end

    HrAccount.create!(employee: employee, email: args[:email], password: password,
      role: role, access_enabled: role == "access_admin")
    puts "Account enrolled for #{employee.employee_number}."
  end

  desc "Disable an Access Admin and invalidate their existing sessions"
  task :disable_admin, [:employee_number] => :environment do |_task, args|
    HrAccount.transaction do
      employee = Employee.find_by!(employee_number: args[:employee_number])
      account = HrAccount.where(role: :access_admin).find_by!(employee: employee)
      account.update!(access_enabled: false, access_version: account.access_version + 1)
      puts "Access Admin disabled for #{employee.employee_number}."
    end
  end
end
