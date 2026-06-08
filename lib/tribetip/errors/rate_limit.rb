# frozen_string_literal: true

module Tribetip
  module Errors
    class RateLimit < Base
      private

      def default_code
        "rate_limited"
      end

      def default_http_status
        :too_many_requests
      end

      def default_message
        "Too many requests. Please try again later."
      end
    end
  end
end
