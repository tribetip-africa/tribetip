# frozen_string_literal: true

module Tribetip
  module Errors
    class Authorization < Base
      private

      def default_code
        "forbidden"
      end

      def default_http_status
        :forbidden
      end

      def default_message
        "You are not allowed to perform this action."
      end
    end
  end
end
