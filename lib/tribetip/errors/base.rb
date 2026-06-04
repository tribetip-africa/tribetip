# frozen_string_literal: true

module Tribetip
  module Errors
    class Base < StandardError
      attr_reader :code, :http_status, :details, :cause

      def initialize(message = nil, code: nil, http_status: nil, details: {}, cause: nil)
        @code = code || default_code
        @http_status = http_status || default_http_status
        @details = details || {}
        @cause = cause
        super(message || default_message)
      end

      def to_h
        {
          code: code,
          message: message,
          details: details.presence
        }.compact
      end

      def as_json(*)
        to_h
      end

      private

      def default_code
        "internal_error"
      end

      def default_http_status
        :internal_server_error
      end

      def default_message
        "Something went wrong."
      end
    end
  end
end
