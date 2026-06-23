# frozen_string_literal: true

module Tribetip
  module Errors
    module JobHelpers
      def run_job_step(context = {}, &block)
        block.call
      rescue Tribetip::Paystack::RateLimited
        raise
      rescue Tribetip::Errors::Base => e
        report_job_error(e, context)
        raise
      rescue StandardError => e
        wrapped = Tribetip::Errors::Internal.new(cause: e)
        report_job_error(wrapped, context, original: e)
        raise wrapped
      end

      private

      def report_job_error(error, context, original: nil)
        source = error.cause || original
        Rails.logger.error(
          "[Tribetip::JobError] #{self.class.name} #{error.code} #{error.message} " \
          "context=#{context.inspect}" \
          "#{source ? " cause=#{source.class}: #{source.message}" : ""}"
        )
      end
    end
  end
end
