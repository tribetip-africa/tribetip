# frozen_string_literal: true

module Tribetip
  module Errors
    class ReauthenticationRequired < Base
      private

      def default_code
        "reauthentication_required"
      end

      def default_http_status
        :forbidden
      end

      def default_message
        "Sign in again to access sensitive payout details."
      end
    end
  end
end
