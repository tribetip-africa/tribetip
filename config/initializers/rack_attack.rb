require Rails.root.join("lib/tribetip/rack_attack_paths")

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

  # Limit public profile enumeration.
  throttle(
    "public_profiles/ip",
    limit: ENV.fetch("RACK_ATTACK_PUBLIC_PROFILE_LIMIT", 60).to_i,
    period: 60.seconds
  ) do |req|
    req.ip if req.get? && req.path.match?(%r{\A/tribes/[a-z0-9_]+\z})
  end

  throttle(
    "share_profiles/ip",
    limit: ENV.fetch("RACK_ATTACK_SHARE_PROFILE_LIMIT", 180).to_i,
    period: 60.seconds
  ) do |req|
    req.ip if req.get? && req.path.match?(%r{\A/share/[A-Za-z0-9_-]{20,48}\z})
  end

  throttle(
    "widget_config/ip",
    limit: ENV.fetch("RACK_ATTACK_WIDGET_CONFIG_LIMIT", 120).to_i,
    period: 60.seconds
  ) do |req|
    req.ip if req.get? && req.path == "/widget/config"
  end

  throttle(
    "tips/ip",
    limit: ENV.fetch("RACK_ATTACK_TIPS_LIMIT", 30).to_i,
    period: 60.seconds
  ) do |req|
    req.ip if req.post? && req.path == "/tips"
  end

  throttle(
    "tip_checkout/ip",
    limit: ENV.fetch("RACK_ATTACK_TIP_CHECKOUT_LIMIT", 30).to_i,
    period: 60.seconds
  ) do |req|
    req.ip if req.get? && req.path.match?(%r{\A/tips/checkout/[A-Za-z0-9_-]+\z})
  end

  throttle(
    "tip_checkout/reference",
    limit: ENV.fetch("RACK_ATTACK_TIP_REFERENCE_LIMIT", 10).to_i,
    period: 60.seconds
  ) do |req|
    req.path if req.get? && req.path.match?(%r{\A/tips/checkout/[A-Za-z0-9_-]+\z})
  end

  throttle(
    "tip_reconcile/ip",
    limit: ENV.fetch("RACK_ATTACK_TIP_RECONCILE_LIMIT", 20).to_i,
    period: 60.seconds
  ) do |req|
    req.ip if req.post? && req.path.match?(%r{\A/tips/[A-Za-z0-9_-]+/reconcile\z})
  end

  throttle(
    "tip_reconcile/reference",
    limit: ENV.fetch("RACK_ATTACK_TIP_REFERENCE_LIMIT", 10).to_i,
    period: 60.seconds
  ) do |req|
    req.path if req.post? && req.path.match?(%r{\A/tips/[A-Za-z0-9_-]+/reconcile\z})
  end

  throttle("paystack_repair/ip", limit: 6, period: 5.minutes) do |req|
    req.ip if req.post? && req.path == "/me/paystack/repair"
  end

  throttle("admin_paystack_repair/ip", limit: 10, period: 5.minutes) do |req|
    req.ip if req.post? && req.path.match?(%r{\A/admin/tribes/[^/]+/repair\z})
  end

  throttle("paystack_withdrawal/ip", limit: 6, period: 5.minutes) do |req|
    req.ip if req.post? && req.path == "/me/paystack/withdrawals"
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
