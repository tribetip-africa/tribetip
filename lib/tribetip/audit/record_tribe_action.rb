# frozen_string_literal: true

module Tribetip
  module Audit
    class RecordTribeAction
      def self.call(tribe:, action:, details: {}, request: nil)
        new(tribe: tribe, action: action, details: details, request: request).call
      end

      def initialize(tribe:, action:, details: {}, request: nil)
        @tribe = tribe
        @action = action
        @details = details
        @request = request
      end

      def call
        log = TribeAuditLog.create!(
          tribe: @tribe,
          action: @action,
          details: @details,
          request_id: @request&.request_id,
          ip: @request&.remote_ip,
          user_agent: @request&.user_agent
        )

        PaymentLogger.log(
          event: "tribe_#{@action}",
          tribe_id: @tribe.id,
          details: @details,
          request_id: log.request_id,
          ip: log.ip
        )

        log
      end
    end
  end
end
