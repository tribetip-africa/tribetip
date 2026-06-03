class Rack::Attack
  # Mitigate brute force against authentication endpoints.
  throttle("auth/ip", limit: 10, period: 60.seconds) do |req|
    if req.post? && req.path.in?([ "/tribes/sign_in", "/tribes/password", "/tribes" ])
      req.ip
    end
  end

  throttle("auth/email", limit: 5, period: 60.seconds) do |req|
    if req.post? && req.path.in?([ "/tribes/sign_in", "/tribes/password" ])
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

  self.throttled_responder = lambda do |_request|
    [ 429, { "Content-Type" => "application/json" }, [ { error: "Too many requests" }.to_json ] ]
  end
end
