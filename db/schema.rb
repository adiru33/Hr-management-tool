# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_19_010100) do
  create_table "account_access_events", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.integer "target_id", null: false
    t.string "action", null: false
    t.date "last_working_on"
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_account_access_events_on_actor_id"
    t.index ["target_id"], name: "index_account_access_events_on_target_id"
  end

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false, collation: "NOCASE"
    t.index ["name"], name: "index_departments_on_name", unique: true
  end

  create_table "employees", force: :cascade do |t|
    t.string "employee_number", null: false
    t.string "full_name", null: false
    t.string "country_code", null: false
    t.integer "department_id", null: false
    t.integer "job_role_id", null: false
    t.date "joined_on", null: false
    t.date "last_working_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_code"], name: "index_employees_on_country_code"
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["employee_number"], name: "index_employees_on_employee_number", unique: true
    t.index ["job_role_id"], name: "index_employees_on_job_role_id"
    t.check_constraint "last_working_on IS NULL OR last_working_on >= joined_on", name: "employees_valid_employment_dates"
  end

  create_table "hr_accounts", force: :cascade do |t|
    t.integer "employee_id", null: false
    t.string "email", null: false, collation: "NOCASE"
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "employee", null: false
    t.boolean "access_enabled", default: false, null: false
    t.integer "access_version", default: 0, null: false
    t.index ["email"], name: "index_hr_accounts_on_email", unique: true
    t.index ["employee_id"], name: "index_hr_accounts_on_employee_id", unique: true
    t.index ["role"], name: "index_hr_accounts_on_role"
    t.check_constraint "role <> 'employee' OR access_enabled = 0", name: "hr_accounts_employee_access_disabled"
    t.check_constraint "role IN ('employee', 'hr_manager', 'access_admin')", name: "hr_accounts_valid_role"
  end

  create_table "job_roles", force: :cascade do |t|
    t.string "name", null: false, collation: "NOCASE"
    t.index ["name"], name: "index_job_roles_on_name", unique: true
  end

  create_table "salary_records", force: :cascade do |t|
    t.integer "employee_id", null: false
    t.integer "amount_minor", null: false
    t.string "currency_code", null: false
    t.date "effective_on", null: false
    t.integer "recorded_by_hr_account_id", null: false
    t.datetime "created_at", null: false
    t.index ["employee_id", "effective_on"], name: "index_salary_records_on_employee_id_and_effective_on", unique: true
    t.index ["recorded_by_hr_account_id"], name: "index_salary_records_on_recorded_by_hr_account_id"
    t.check_constraint "typeof(amount_minor) = 'integer' AND amount_minor > 0", name: "salary_records_positive_integer_amount"
  end

  add_foreign_key "account_access_events", "hr_accounts", column: "actor_id"
  add_foreign_key "account_access_events", "hr_accounts", column: "target_id"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "job_roles"
  add_foreign_key "hr_accounts", "employees"
  add_foreign_key "salary_records", "employees"
  add_foreign_key "salary_records", "hr_accounts", column: "recorded_by_hr_account_id"
end
