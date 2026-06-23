require Rails.root.join("lib/tribetip/rack_attack_paths")
require Rails.root.join("lib/tribetip/rack_attack_keys")

class Rack::Attack
  # Mitigate brute force against authentication endpoints.
  throttle("auth/ip", limit: 10, period: 60.seconds) do |req|
    req.ip if Tribetip::RackAttackPaths.auth_path?(req)
  end

  throttle("auth/email", limit: 5, period: 60.seconds) do |req|
    if Tribetip::RackAttackPaths.sign_in_path?(req) || Tribetip::RackAttackPaths.password_path?(req)
      req.params["tribe"]&.[]("email")&.to_s&.downcase&.strip
    end
  end

  # Per viewer IP + creator username so one profile cannot exhaust another's bucket.
  throttle(
    "public_profiles/view",
    limit: ENV.fetch("RACK_ATTACK_PUBLIC_PROFILE_LIMIT", 60).to_i,
    period: 60.seconds
  ) do |req|
    Tribetip::RackAttackKeys.profile_view(req) if Tribetip::RackAttackPaths.public_profile_path?(req)
  end

  throttle(
    "share_profiles/view",
    limit: ENV.fetch("RACK_ATTACK_SHARE_PROFILE_LIMIT", 180).to_i,
    period: 60.seconds
  ) do |req|
    Tribetip::RackAttackKeys.share_profile_view(req) if Tribetip::RackAttackPaths.share_profile_path?(req)
  end

  throttle(
    "widget_config/view",
    limit: ENV.fetch("RACK_ATTACK_WIDGET_CONFIG_LIMIT", 120).to_i,
    period: 60.seconds
  ) do |req|
    Tribetip::RackAttackKeys.widget_config_view(req) if Tribetip::RackAttackPaths.widget_config_path?(req)
  end

  # Per supporter IP + target creator so unrelated creators are not blocked together.
  throttle(
    "tips/create",
    limit: ENV.fetch("RACK_ATTACK_TIPS_LIMIT", 30).to_i,
    period: 60.seconds
  ) do |req|
    Tribetip::RackAttackKeys.tip_create(req)
  end

  # Per checkout reference (one tip session), not a shared IP bucket.
  throttle(
    "tip_checkout/reference",
    limit: ENV.fetch("RACK_ATTACK_TIP_CHECKOUT_LIMIT", 30).to_i,
    period: 60.seconds
  ) do |req|
    Tribetip::RackAttackKeys.tip_checkout_poll(req) if req.get? && req.path.match?(Tribetip::RackAttackKeys::TIP_CHECKOUT_PATTERN)
  end

  throttle(
    "tip_reconcile/reference",
    limit: ENV.fetch("RACK_ATTACK_TIP_RECONCILE_LIMIT", 20).to_i,
    period: 60.seconds
  ) do |req|
    Tribetip::RackAttackKeys.tip_reconcile(req) if req.post? && req.path.match?(Tribetip::RackAttackKeys::TIP_RECONCILE_PATTERN)
  end

  throttle("paystack_repair/account", limit: 6, period: 5.minutes) do |req|
    Tribetip::RackAttackKeys.bearer_account(req) if req.post? && req.path == "/me/paystack/repair"
  end

  throttle("admin_paystack_repair/ip", limit: 10, period: 5.minutes) do |req|
    req.ip if req.post? && req.path.match?(%r{\A/admin/tribes/[^/]+/repair\z})
  end

  throttle("paystack_withdrawal/account", limit: 6, period: 5.minutes) do |req|
    Tribetip::RackAttackKeys.bearer_account(req) if req.post? && req.path == "/me/paystack/withdrawals"
  end

  throttle(
    "paystack_account_number/account",
    limit: ENV.fetch("RACK_ATTACK_ACCOUNT_NUMBER_REVEAL_LIMIT", 6).to_i,
    period: 5.minutes
  ) do |req|
    Tribetip::RackAttackKeys.bearer_account(req) if Tribetip::RackAttackPaths.account_number_reveal_path?(req)
  end

  throttle("session_refresh/account", limit: 12, period: 5.minutes) do |req|
    Tribetip::RackAttackKeys.bearer_account(req) if Tribetip::RackAttackPaths.session_refresh_path?(req)
  end

  self.throttled_responder = lambda do |_request|
    tribetip_error = Tribetip::Errors::RateLimit.new
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: tribetip_error.to_h }.to_json ]
    ]
  end
end
