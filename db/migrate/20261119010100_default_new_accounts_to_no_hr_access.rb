class DefaultNewAccountsToNoHrAccess < ActiveRecord::Migration[8.1]
  def change
    change_column_default :hr_accounts, :access_enabled, from: true, to: false
    change_column_default :hr_accounts, :role, from: "hr_manager", to: "employee"
  end
end
