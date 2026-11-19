module Api
  class AccessAccountsController < BaseController
    PAGE_SIZE = 25

    before_action :require_access_admin

    def index
      accounts = HrAccount.where(role: %i[employee hr_manager]).joins(:employee)
      search = params[:search].to_s.strip.first(100)
      if search.present?
        pattern = "%#{HrAccount.sanitize_sql_like(search, "!")}%"
        accounts = accounts.where(
          "employees.full_name LIKE :pattern ESCAPE '!' OR employees.employee_number LIKE :pattern ESCAPE '!' OR hr_accounts.email LIKE :pattern ESCAPE '!'",
          pattern: pattern
        )
      end

      total = accounts.count
      page = params[:page].to_s.to_i.clamp(1, [(total + PAGE_SIZE - 1) / PAGE_SIZE, 1].max)
      entries = accounts.includes(:employee).order("employees.full_name", :id)
        .offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE)
      render json: { accounts: entries.map { |account| account_data(account) }, page: page, pageSize: PAGE_SIZE, total: total }
    end

    def update
      input = params.permit(:operation, :last_working_on)
      account = ManageHrAccess.new(actor: current_account, date: business_date).call(
        target_id: params[:id], action: input[:operation], last_working_on: input[:last_working_on]
      )
      render json: account_data(account)
    rescue ManageHrAccess::InvalidOperation => error
      render json: { error: error.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => error
      render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    rescue ActiveRecord::StatementTimeout
      render json: { error: "The database is busy. Please try again." }, status: :service_unavailable
    end

    private

    def account_data(account)
      employee = account.employee
      active = account.sign_in_allowed_on?(business_date)
      can_grant = !account.access_enabled? && account.active_on?(business_date)
      status = if active
        "Active"
      elsif account.role_employee?
        can_grant ? "Ready to grant" : "Ineligible"
      else
        account.access_enabled? ? "Inactive" : "Revoked"
      end

      {
        id: account.id, number: employee.employee_number, name: employee.full_name, email: account.email,
        role: account.role, accessEnabled: account.access_enabled?, status: status, canGrant: can_grant,
        canRecordDeparture: account.role_hr_manager?,
        joinedOn: employee.joined_on, lastWorkingOn: employee.last_working_on
      }
    end
  end
end
