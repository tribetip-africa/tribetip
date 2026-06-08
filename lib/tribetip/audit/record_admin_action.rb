# frozen_string_literal: true

module Tribetip
  module Audit
    class RecordAdminAction
      def self.call(admin:, action:, target:, details: {}, request: nil)
        new(admin: admin, action: action, target: target, details: details, request: request).call
      end

      def initialize(admin:, action:, target:, details: {}, request: nil)
        @admin = admin
        @action = action
        @target = target
        @details = details
        @request = request
      end

      def call
        log = AdminAuditLog.create!(
          admin: @admin,
          action: @action,
          target_type: @target.class.name,
          target_id: @target.id.to_s,
          details: @details,
          request_id: @request&.request_id,
          ip: @request&.remote_ip,
          user_agent: @request&.user_agent
        )

        PaymentLogger.log(
          event: "admin_#{@action}",
          admin_id: @admin.id,
          target_type: log.target_type,
          target_id: log.target_id,
          details: @details
        )

        log
      end
    end
  end
end
