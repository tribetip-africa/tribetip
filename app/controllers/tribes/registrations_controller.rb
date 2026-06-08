module Tribes
  class RegistrationsController < Devise::RegistrationsController
    include DatabaseRouting
    include SecureHttpCaching
    include Tribetip::Errors::Handler
    include TribeSerializable

    respond_to :json

    def create
      apply_http_cache_policy(:no_store)
      build_resource(sign_up_params)
      resource.role = "creator"
      resource.skip_confirmation! unless Tribetip::Security.require_email_confirmation?
      resource.save

      if resource.persisted?
        message = if resource.confirmed?
          "Signed up successfully."
        else
          "Signed up successfully. Please confirm your email before signing in."
        end

        render json: {
          message: message,
          tribe: tribe_json(resource.reload),
          confirmation_required: !resource.confirmed?
        }, status: :created
      else
        render_error(
          Tribetip::Errors::Validation.new(
            "Validation failed.",
            details: { errors: resource.errors.full_messages }
          )
        )
      end
    end

    private

    def respond_with(resource, _opts = {})
      if resource.persisted?
        render json: {
          message: "Signed up successfully.",
          tribe: tribe_json(resource)
        }, status: :created
      else
        render_error(
          Tribetip::Errors::Validation.new(
            "Validation failed.",
            details: { errors: resource.errors.full_messages }
          )
        )
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
