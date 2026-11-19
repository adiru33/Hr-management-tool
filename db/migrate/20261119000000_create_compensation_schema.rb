class CreateCompensationSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :departments do |t|
      t.string :name, null: false, collation: "NOCASE"
      t.index :name, unique: true
    end

    create_table :job_roles do |t|
      t.string :name, null: false, collation: "NOCASE"
      t.index :name, unique: true
    end

    create_table :employees do |t|
      t.string :employee_number, null: false
      t.string :full_name, null: false
      t.string :country_code, null: false
      t.references :department, null: false, foreign_key: true
      t.references :job_role, null: false, foreign_key: true
      t.date :joined_on, null: false
      t.date :last_working_on
      t.timestamps

      t.index :employee_number, unique: true
      t.index :country_code
      t.check_constraint "last_working_on IS NULL OR last_working_on >= joined_on",
        name: "employees_valid_employment_dates"
    end

    create_table :hr_accounts do |t|
      t.references :employee, null: false, foreign_key: true, index: { unique: true }
      t.string :email, null: false, collation: "NOCASE"
      t.string :password_digest, null: false
      t.timestamps

      t.index :email, unique: true
    end

    create_table :salary_records do |t|
      t.references :employee, null: false, foreign_key: true, index: false
      t.integer :amount_minor, null: false
      t.string :currency_code, null: false
      t.date :effective_on, null: false
      t.references :recorded_by_hr_account, null: false, foreign_key: { to_table: :hr_accounts }
      t.datetime :created_at, null: false

      t.index [:employee_id, :effective_on], unique: true
      t.check_constraint "typeof(amount_minor) = 'integer' AND amount_minor > 0",
        name: "salary_records_positive_integer_amount"
    end
  end
end
