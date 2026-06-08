# frozen_string_literal: true

module Tribetip
  module Errors
    class Internal < Base
      private

      def default_code
        "internal_error"
      end

      def default_http_status
        :internal_server_error
      end

      def default_message
        "Something went wrong on our end."
      end
    end
  end
end
