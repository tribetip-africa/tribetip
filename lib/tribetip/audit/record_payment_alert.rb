# frozen_string_literal: true

module Tribetip
  module Audit
    class RecordPaymentAlert
      def self.call(kind:, title:, body:, metadata: {}, severity: "warning")
        new(kind: kind, title: title, body: body, metadata: metadata, severity: severity).call
      end

      def initialize(kind:, title:, body:, metadata: {}, severity: "warning")
        @kind = kind
        @title = title
        @body = body
        @metadata = metadata
        @severity = severity
      end

      def call
        return if duplicate?

        alert = PaymentAlert.create!(
          kind: @kind,
          severity: @severity,
          title: @title,
          body: @body,
          metadata: @metadata
        )

        PaymentLogger.log(
          event: @kind,
          payment_alert_id: alert.id,
          metadata: @metadata
        )

        alert
      end

      private

      def duplicate?
        scope = PaymentAlert.unresolved.where(kind: @kind)
        audit_key = @metadata[:audit_key] || @metadata["audit_key"]
        if audit_key.present?
          return scope.where("metadata->>'audit_key' = ?", audit_key.to_s).exists?
        end

        transfer_code = @metadata[:transfer_code] || @metadata["transfer_code"]
        return false if transfer_code.blank?

        scope.where("metadata->>'transfer_code' = ?", transfer_code.to_s).exists?
      end
    end
  end
end
