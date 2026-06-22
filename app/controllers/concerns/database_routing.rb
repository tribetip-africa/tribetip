# frozen_string_literal: true

module DatabaseRouting
  extend ActiveSupport::Concern

  included do
    around_action :route_database_by_request
  end

  private

  def route_database_by_request
    if force_primary_connection?
      ActiveRecord::Base.connected_to(role: :writing) { yield }
    else
      yield
    end
  end

  def force_primary_connection?
    return true if request.path == "/up"
    return true if public_tip_checkout_request?
    return true if devise_auth_request?
    return true if authenticated_api_request?

    request.post? || request.put? || request.patch? || request.delete?
  end

  def public_tip_checkout_request?
    request.get? && request.path.match?(%r{\A/tips/checkout/})
  end

  def authenticated_api_request?
    return true if request.path.start_with?("/me/")

    authorization = request.headers["Authorization"]
    authorization.present? && authorization.start_with?("Bearer ")
  end

  def devise_auth_request?
    path = request.path
    return true if path.start_with?(
      "/tribes/sign_in",
      "/tribes/sign_out",
      "/tribes/password",
      "/tribes/confirmation",
      "/tribes/unlock"
    )

    request.post? && path == "/tribes"
  end
end
