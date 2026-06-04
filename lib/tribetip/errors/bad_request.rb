# frozen_string_literal: true

module Tribetip
  module Errors
    class BadRequest < Base
      private

      def default_code
        "bad_request"
      end

      def default_http_status
        :bad_request
      end

      def default_message
        "The request could not be understood."
      end
    end
  end
end
