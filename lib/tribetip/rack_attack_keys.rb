# frozen_string_literal: true

module Tribetip
  module RackAttackKeys
    PROFILE_PATTERN = %r{\A/tribes/([a-z0-9_]+)\z}
    TIP_CHECKOUT_PATTERN = %r{\A/tips/checkout/([A-Za-z0-9_-]+)\z}
    TIP_RECONCILE_PATTERN = %r{\A/tips/([A-Za-z0-9_-]+)/reconcile\z}

    module_function

    def profile_view(req)
      return unless req.path.match?(Tribetip::RackAttackPaths::PUBLIC_PROFILE_PATTERN)

      username = req.path.delete_prefix("/tribes/")
      return if username.blank?

      "profile:#{req.ip}:#{username}"
    end

    def share_profile_view(req)
      match = req.path.match(Tribetip::RackAttackPaths::SHARE_PROFILE_PATTERN)
      return unless match

      token = match[1]
      "share:#{req.ip}:#{token}"
    end

    def widget_config_view(req)
      "widget:#{req.ip}"
    end

    def tip_create(req)
      return unless req.post? && req.path == "/tips"

      username = request_params(req).dig("tip", "username").to_s.strip.downcase
      return if username.blank?

      "tip-create:#{req.ip}:#{username}"
    end

    def tip_checkout_poll(req)
      reference = req.path[TIP_CHECKOUT_PATTERN, 1]
      return if reference.blank?

      "tip-checkout:#{req.ip}:#{reference}"
    end

    def tip_reconcile(req)
      reference = req.path[TIP_RECONCILE_PATTERN, 1]
      return if reference.blank?

      "tip-reconcile:#{req.ip}:#{reference}"
    end

    def bearer_account(req)
      authorization = req.get_header("HTTP_AUTHORIZATION").to_s
      return unless authorization.start_with?("Bearer ")

      token = authorization.delete_prefix("Bearer ").strip
      return if token.blank?

      "account:#{Digest::SHA256.hexdigest(token)[0, 16]}"
    end

    def request_params(req)
      ActionDispatch::Request.new(req.env).params
    rescue StandardError
      {}
    end
  end
end
