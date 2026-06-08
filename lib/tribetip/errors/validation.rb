# frozen_string_literal: true

module Tribetip
  module Errors
    class Validation < Base
      private

      def default_code
        "validation_failed"
      end

      def default_http_status
        :unprocessable_content
      end

      def default_message
        "Validation failed."
      end
    end
  end
end
