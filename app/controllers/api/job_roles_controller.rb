module Api
  class JobRolesController < BaseController
    before_action :require_hr_account
    rescue_from ActiveRecord::RecordInvalid, with: :invalid_role
    rescue_from ActiveRecord::RecordNotUnique, with: :duplicate_role

    def index
      render json: { roles: JobRole.order(:name, :id).map { |role| role_data(role) } }
    end

    def create
      role = JobRole.create!(role_params)
      render json: role_data(role), status: :created
    end

    def update
      role = JobRole.find(params[:id])
      role.update!(role_params)
      render json: role_data(role)
    end

    private

    def role_params
      params.permit(:name)
    end

    def role_data(role)
      { id: role.id, name: role.name }
    end

    def invalid_role(error)
      render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    def duplicate_role
      render json: { error: "That job role name already exists." }, status: :unprocessable_entity
    end
  end
end
