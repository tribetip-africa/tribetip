# frozen_string_literal: true

module AuthenticatedTribe
  extend ActiveSupport::Concern

  included do
    prepend_before_action :enforce_tribe_not_suspended, if: :bearer_token_provided?
  end

  private

  def bearer_token_provided?
    bearer_token.present?
  end

  def bearer_token
    authorization = request.headers["Authorization"]
    return if authorization.blank?
    return unless authorization.start_with?("Bearer ")

    authorization.delete_prefix("Bearer ").strip
  end

  def enforce_tribe_not_suspended
    tribe = authenticated_tribe_from_token
    return unless tribe&.suspended?

    render_error(Tribetip::Errors::Authorization.new("Account suspended."))
  end

  def authenticated_tribe_from_token
    warden.user(:tribe) || decode_tribe_from_bearer_token
  end

  def decode_tribe_from_bearer_token
    payload = Warden::JWTAuth::TokenDecoder.new.call(bearer_token)
    return unless payload["scp"] == "tribe"

    Tribe.find_by(id: payload["sub"])
  rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError
    nil
  end
end
