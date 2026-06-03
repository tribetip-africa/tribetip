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
    return true if devise_auth_request?

    request.post? || request.put? || request.patch? || request.delete?
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
