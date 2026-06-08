# frozen_string_literal: true

module Tribetip
  module Audit
    class PaymentLogger
      def self.log(event:, **attrs)
        payload = {
          audit: "payment",
          event: event,
          at: Time.current.iso8601(3)
        }.merge(attrs).compact

        Rails.logger.info(payload.to_json)
      end
    end
  end
end
