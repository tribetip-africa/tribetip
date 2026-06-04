module Tribes
  class SessionsController < Devise::SessionsController
    include DatabaseRouting
    include SecureHttpCaching

    respond_to :json

    prepend_before_action :normalize_sign_in_params, only: :create

    private

    def normalize_sign_in_params
      tribe = sign_in_tribe_params
      return if tribe.blank?

      login = tribe["login"].presence || tribe[:login].presence
      password = tribe["password"].presence || tribe[:password]
      return if login.blank? || password.blank?

      params[:tribe] = ActionController::Parameters.new(
        login: login.to_s.strip.downcase,
        password: password
      ).permit(:login, :password)
    end

    # :email and :password match filter_parameters and become "[FILTERED]" in params.
    def sign_in_tribe_params
      return raw_sign_in_json_params if request.content_type.to_s.include?("application/json")

      params.to_unsafe_h["tribe"] || params.to_unsafe_h[:tribe] || {}
    end

    def raw_sign_in_json_params
      rack_input = request.env["rack.input"]
      return {} unless rack_input

      rack_input.rewind if rack_input.respond_to?(:rewind)
      body = rack_input.read
      rack_input.rewind if rack_input.respond_to?(:rewind)
      return {} if body.blank?

      JSON.parse(body).fetch("tribe", {})
    rescue JSON::ParserError
      {}
    end

    def respond_with(resource, _opts = {})
      apply_http_cache_policy(:no_store)
      render json: tribe_payload(resource), status: :ok
    end

    def respond_to_on_destroy(_opts = {})
      apply_http_cache_policy(:no_store)
      if current_tribe
        render json: { message: "Signed out successfully." }, status: :ok
      else
        render_error(Tribetip::Errors::Authentication.new("No active session."))
      end
    end

    def tribe_payload(tribe)
      token, _payload = Warden::JWTAuth::UserEncoder.new.call(tribe, :tribe, nil)

      {
        message: "Signed in successfully.",
        token: token,
        tribe: {
          id: tribe.id,
          email: tribe.email,
          username: tribe.username
        }
      }
    end
  end
end
