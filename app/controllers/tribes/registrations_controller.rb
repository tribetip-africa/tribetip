module Tribes
  class RegistrationsController < Devise::RegistrationsController
    respond_to :json

    def create
      build_resource(sign_up_params)
      resource.skip_confirmation!
      resource.save

      if resource.persisted?
        render json: {
          message: "Signed up successfully.",
          tribe: {
            id: resource.id,
            email: resource.email,
            username: resource.username
          }
        }, status: :created
      else
        render json: { errors: resource.errors.full_messages }, status: :unprocessable_content
      end
    end

    private

    def respond_with(resource, _opts = {})
      if resource.persisted?
        render json: {
          message: "Signed up successfully.",
          tribe: {
            id: resource.id,
            email: resource.email,
            username: resource.username
          }
        }, status: :created
      else
        render json: { errors: resource.errors.full_messages }, status: :unprocessable_content
      end
    end

    def sign_up_params
      params.require(:tribe).permit(
        :email,
        :password,
        :password_confirmation,
        :username,
        :display_name,
        :country_code,
        :currency
      )
    end
  end
end
