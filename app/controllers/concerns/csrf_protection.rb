# frozen_string_literal: true

module CsrfProtection
  extend ActiveSupport::Concern

  included do
    before_action :verify_csrf_for_cookie_auth!
  end

  private

  def verify_csrf_for_cookie_auth!
    return unless Tribetip::Security::AuthCookie.enabled?
    return unless mutating_request?
    return if csrf_exempt_path?
    return unless cookie_authenticated_request?

    unless valid_csrf_token?
      render_error(Tribetip::Errors::Authorization.new("Invalid CSRF token."))
    end
  end

  def cookie_authenticated_request?
    request.env["tribetip.jwt_from_cookie"] == "1" &&
      Tribetip::Security::AuthCookie.read(cookies).present?
  end

  def bearer_token_from_header
    authorization = request.headers["Authorization"]
    return if authorization.blank?
    return unless authorization.start_with?("Bearer ")

    authorization.delete_prefix("Bearer ").strip
  end

  def mutating_request?
    request.post? || request.put? || request.patch? || request.delete?
  end

  def csrf_exempt_path?
    path = request.path
    return true if path == "/paystack/webhook"
    return true if path == "/up"
    return true if path.start_with?("/tribes/sign_in")

    false
  end

  def valid_csrf_token?
    header = request.headers["X-CSRF-Token"].to_s
    cookie = cookies[Tribetip::Security::AuthCookie::CSRF_COOKIE].to_s
    return false if header.blank? || cookie.blank?

    ActiveSupport::SecurityUtils.secure_compare(header, cookie)
  end
end
