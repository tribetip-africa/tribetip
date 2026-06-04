# frozen_string_literal: true

module Tribetip
  module Errors
    class NotFound < Base
      private

      def default_code
        "not_found"
      end

      def default_http_status
        :not_found
      end

      def default_message
        "Resource not found."
      end
    end
  end
end
