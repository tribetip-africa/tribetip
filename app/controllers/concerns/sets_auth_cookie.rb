# frozen_string_literal: true

module SetsAuthCookie
  extend ActiveSupport::Concern

  private

  def issue_auth_cookies!(token)
    Tribetip::Security::AuthCookie.write(cookies: cookies, token: token)
  end

  def clear_auth_cookies!
    Tribetip::Security::AuthCookie.clear(cookies)
  end
end
