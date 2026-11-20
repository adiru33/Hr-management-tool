class AddHrAccessHandover < ActiveRecord::Migration[8.1]
  def change
    change_column_null :hr_accounts, :email, true
    add_column :hr_accounts, :password_change_required, :boolean, default: false, null: false
    add_check_constraint :hr_accounts, "email IS NOT NULL OR access_enabled = 0",
      name: "hr_accounts_require_email_for_access"
    add_reference :account_access_events, :outgoing_account, foreign_key: { to_table: :hr_accounts }
  end
end
