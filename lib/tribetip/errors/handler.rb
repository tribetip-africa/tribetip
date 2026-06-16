# frozen_string_literal: true

module Tribetip
  module Errors
    module Handler
      extend ActiveSupport::Concern

      included do
        unless Rails.application.config.consider_all_requests_local
          rescue_from StandardError, with: :render_internal_error
        end

        rescue_from Tribetip::Errors::Base, with: :render_tribetip_error
        rescue_from ActiveRecord::RecordNotFound, with: :render_record_not_found
        rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
        rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
        rescue_from ActionController::BadRequest, with: :render_bad_request
      end

      private

      def render_tribetip_error(exception)
        log_tribetip_error(exception)
        render json: error_payload(exception), status: exception.http_status
      end

      def render_record_not_found(exception)
        error = Tribetip::Errors::NotFound.new(
          exception.message.presence,
          details: { resource: exception.model&.underscore }
        )
        render_tribetip_error(error)
      end

      def render_record_invalid(exception)
        error = Tribetip::Errors::Validation.new(
          "Validation failed.",
          details: { errors: exception.record.errors.full_messages }
        )
        render_tribetip_error(error)
      end

      def render_parameter_missing(exception)
        error = Tribetip::Errors::BadRequest.new(
          exception.message,
          details: { param: exception.param }
        )
        render_tribetip_error(error)
      end

      def render_bad_request(exception)
        error = Tribetip::Errors::BadRequest.new(exception.message)
        render_tribetip_error(error)
      end

      def render_internal_error(exception)
        wrapped = Tribetip::Errors::Internal.new(cause: exception)
        log_tribetip_error(wrapped, original: exception)
        render json: error_payload(wrapped), status: wrapped.http_status
      end

      def render_error(error)
        render_tribetip_error(error)
      end

      def error_payload(exception)
        payload = { error: exception.to_h }
        legacy = legacy_error_fields(exception)
        payload.merge!(legacy) if legacy.present?
        payload
      end

      def legacy_error_fields(exception)
        case exception
        when Tribetip::Errors::Validation
          errors = exception.details[:errors] || exception.details["errors"]
          return { errors: errors } if errors.present?

          nil
        when Tribetip::Errors::Authentication, Tribetip::Errors::Authorization
          nil
        else
          nil
        end
      end

      def log_tribetip_error(exception, original: nil)
        source = exception.cause || original
        Rails.logger.warn(
          "[Tribetip::Error] #{exception.code} #{exception.message} " \
          "status=#{exception.http_status} details=#{exception.details.inspect}" \
          "#{source ? " cause=#{source.class}: #{source.message}" : ""}"
        )
      end
    end
  end
end
