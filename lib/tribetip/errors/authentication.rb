# frozen_string_literal: true

module Tribetip
  module Errors
    class Authentication < Base
      private

      def default_code
        "authentication_failed"
      end

      def default_http_status
        :unauthorized
      end

      def default_message
        "Authentication required."
      end
    end
  end
end
