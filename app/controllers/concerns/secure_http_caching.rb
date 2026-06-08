# frozen_string_literal: true

module SecureHttpCaching
  extend ActiveSupport::Concern

  POLICIES = {
    no_store: {
      "Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0, private",
      "Pragma" => "no-cache",
      "Expires" => "0"
    },
    private_no_store: {
      "Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0, private",
      "Pragma" => "no-cache",
      "Expires" => "0",
      "Vary" => "Authorization, Accept"
    },
    health: {
      "Cache-Control" => "no-cache, max-age=0, must-revalidate",
      "Pragma" => "no-cache"
    },
    public_short: {
      "Cache-Control" => "public, max-age=60, stale-while-revalidate=30",
      "Vary" => "Accept"
    }
  }.freeze

  included do
    # Run after other callbacks so cache headers cannot be overwritten.
    prepend_after_action :apply_secure_http_cache_headers
  end

  def apply_http_cache_policy(policy)
    @http_cache_policy = policy
    apply_secure_http_cache_headers
  end

  private

  def apply_secure_http_cache_headers
    policy = @http_cache_policy || inferred_http_cache_policy
    POLICIES.fetch(policy).each { |name, value| headers[name] = value }
  end

  def inferred_http_cache_policy
    return :health if request.path == "/up"
    return :no_store if non_cacheable_request?

    :public_short if public_read_request?

    :no_store
  end

  def non_cacheable_request?
    return true if request.headers["Authorization"].present?
    return true if devise_auth_request?
    return true if request.post? || request.put? || request.patch? || request.delete?

    false
  end

  def public_read_request?
    request.get? && request.path.match?(%r{\A/tribes/[a-z0-9_]+\z})
  end
end
