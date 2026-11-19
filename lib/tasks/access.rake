require "io/console"

namespace :access do
  read_password = lambda do
    console = IO.console or abort "Run this task in an interactive terminal."
    password = console.getpass("Password: ")
    unless password && password.length >= 12 && password.bytesize <= 72 && password == console.getpass("Confirm password: ")
      abort "Passwords must match and contain at least 12 characters and at most 72 bytes."
    end
    password
  end

  desc "Enroll a verified employee or Access Admin account"
  task :enroll, [:employee_number, :email, :role] => :environment do |_task, args|
    role = args[:role] || "employee"
    unless args[:employee_number].present? && args[:email].present? && %w[employee access_admin].include?(role)
      abort "Usage: bin/rails 'access:enroll[EMPLOYEE_NUMBER,WORK_EMAIL,employee|access_admin]'"
    end

    employee = Employee.find_by!(employee_number: args[:employee_number])
    abort "This employee already has an enrolled account." if employee.hr_account
    HrAccount.create!(employee: employee, email: args[:email], password: read_password.call,
      role: role, access_enabled: role == "access_admin")
    puts "Account enrolled for #{employee.employee_number}."
  end

  desc "Reset an enrolled account password and revoke all of its existing sessions"
  task :reset_password, [:employee_number] => :environment do |_task, args|
    employee = Employee.find_by!(employee_number: args[:employee_number])
    account = HrAccount.find_by!(employee: employee)
    password = read_password.call
    unless account.reset_password_and_revoke_sessions(password, password)
      abort account.errors.full_messages.to_sentence
    end

    puts "Password reset for #{employee.employee_number}. Existing sessions were revoked."
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
