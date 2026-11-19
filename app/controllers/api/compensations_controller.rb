module Api
  class CompensationsController < BaseController
    before_action :require_hr_account

    def show
      filters = params.permit(:country, :department, :role).to_h.symbolize_keys
      groups = CompensationOverview.new(as_of: business_date, filters: filters).call

      render json: {
        asOf: business_date,
        groups: groups,
        total: groups.sum { |group| group.fetch(:headcount) },
        filters: Employee.organization_options
      }
    end
  end
end
