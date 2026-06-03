module Tribes
  class SessionsController < Devise::SessionsController
    respond_to :json

    private

    def respond_with(resource, _opts = {})
      render json: tribe_payload(resource), status: :ok
    end

    def respond_to_on_destroy(_opts = {})
      if current_tribe
        render json: { message: "Signed out successfully." }, status: :ok
      else
        render json: { error: "No active session." }, status: :unauthorized
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
