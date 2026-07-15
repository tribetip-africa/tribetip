module Tribes
  class RegistrationsController < Devise::RegistrationsController
    include DatabaseRouting
    include SecureHttpCaching
    include Tribetip::Errors::Handler
    include TribeSerializable

    respond_to :json

    def create
      apply_http_cache_policy(:no_store)
      signup_attributes = sign_up_params
      referral_code = signup_attributes.delete(:referral_code)
      early_access_token = signup_attributes.delete(:early_access_token)

      invite = Tribetip::EarlyAccess::AttachOnSignup.call(
        email: signup_attributes[:email],
        token: early_access_token
      )

      build_resource(signup_attributes)
      resource.role = "creator"
      resource.skip_confirmation! unless Tribetip::Security.require_email_confirmation?

      ActiveRecord::Base.transaction do
        resource.save!
        invite&.burn!(tribe: resource)
      end

      Tribetip::Referrals::AttachOnSignup.call(
        referred: resource,
        referral_code: referral_code,
        signup_ip: request.remote_ip
      )

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
    rescue ActiveRecord::RecordInvalid
      render_error(
        Tribetip::Errors::Validation.new(
          "Validation failed.",
          details: { errors: resource.errors.full_messages }
        )
      )
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
        :currency,
        :referral_code,
        :early_access_token
      )
    end
  end
end
