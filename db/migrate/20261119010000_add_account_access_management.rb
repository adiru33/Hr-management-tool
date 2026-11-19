class AddAccountAccessManagement < ActiveRecord::Migration[8.1]
  def change
    add_column :hr_accounts, :role, :string, null: false, default: "hr_manager"
    add_column :hr_accounts, :access_enabled, :boolean, null: false, default: true
    add_column :hr_accounts, :access_version, :integer, null: false, default: 0
    add_index :hr_accounts, :role
    add_check_constraint :hr_accounts, "role IN ('employee', 'hr_manager', 'access_admin')",
      name: "hr_accounts_valid_role"
    add_check_constraint :hr_accounts, "role <> 'employee' OR access_enabled = 0",
      name: "hr_accounts_employee_access_disabled"

    create_table :account_access_events do |t|
      t.references :actor, null: false, foreign_key: { to_table: :hr_accounts }
      t.references :target, null: false, foreign_key: { to_table: :hr_accounts }
      t.string :action, null: false
      t.date :last_working_on
      t.datetime :created_at, null: false
    end
  end
end
