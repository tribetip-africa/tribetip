# frozen_string_literal: true

module Tribetip
  module Paystack
    class ReconcilePlatform
      Finding = Struct.new(:kind, :severity, :title, :body, :metadata, keyword_init: true) do
        def as_json(*)
          {
            kind: kind,
            severity: severity,
            title: title,
            body: body,
            metadata: metadata
          }
        end
      end

      Report = Struct.new(
        :checked_at,
        :auto_repair,
        :repairs,
        :summary,
        :findings,
        keyword_init: true
      ) do
        def as_json(*)
          {
            checked_at: checked_at,
            auto_repair: auto_repair,
            repairs: repairs,
            summary: summary,
            findings: findings.map(&:as_json)
          }
        end
      end

      REPORT_CACHE_KEY = "paystack/platform_reconciliation/latest"
      REPORT_CACHE_TTL = 7.days

      CREATOR_BATCH_SIZE = 25
      TIP_VERIFY_LIMIT = 25
      PENDING_AGE = 15.minutes
      UNSETTLED_GRACE = 48.hours
      SETTLEMENT_LOOKBACK = 30.days

      def self.call(auto_repair: true)
        new(auto_repair: auto_repair).call
      end

      def initialize(auto_repair: true)
        @auto_repair = auto_repair
        @client = Client.new
        @findings = []
        @repairs = {
          pending_tips_reconciled: 0,
          creators_synced: 0
        }
      end

      def call
        repairs = @auto_repair ? run_auto_repair! : @repairs

        check_stale_pending_tips
        check_failed_webhook_backlog
        check_paid_tips_against_paystack unless @client.stub_mode?
        check_unsettled_paid_tips
        check_settlement_status_drift unless @client.stub_mode?

        creators_for_batch.find_each do |tribe|
          check_onboarding_drift(tribe)
        end

        findings = @findings.dup
        findings.each { |finding| record_alert!(finding) }

        report = Report.new(
          checked_at: Time.current.iso8601,
          auto_repair: @auto_repair,
          repairs: repairs,
          summary: build_summary(findings),
          findings: findings
        )

        cache_report!(report)
        log_report!(report)

        report
      end

      private

      def run_auto_repair!
        Tip.pending_older_than(PENDING_AGE).order(created_at: :asc).limit(100).find_each do |tip|
          result = ReconcileTipPayment.call(tip, paid_via: :sweep)
          @repairs[:pending_tips_reconciled] += 1 if result.success?
        rescue Tribetip::Errors::Base => error
          Rails.logger.warn(
            "[ReconcilePlatform] tip=#{tip.id} reference=#{tip.paystack_reference} repair_error=#{error.message}"
          )
        end

        creators_for_batch.find_each do |tribe|
          ListSettlements.call(tribe, refresh: true)
          @repairs[:creators_synced] += 1
        rescue StandardError => error
          Rails.logger.warn(
            "[ReconcilePlatform] tribe=#{tribe.id} username=#{tribe.username} sync_error=#{error.message}"
          )
        end

        @repairs
      end

      def creators_for_batch
        Tribe.where(role: "creator")
             .where.not(paystack_subaccount_code: [ nil, "" ])
             .order(updated_at: :asc)
             .limit(CREATOR_BATCH_SIZE)
      end

      def check_stale_pending_tips
        count = Tip.pending_older_than(PENDING_AGE).count
        return if count.zero?

        add_finding(
          kind: "stale_pending_tips",
          severity: count >= 10 ? "critical" : "warning",
          title: "Stale pending tips detected",
          body: "#{count} tip(s) remain pending after #{PENDING_AGE.inspect}.",
          metadata: {
            audit_key: "platform:stale_pending_tips",
            count: count,
            pending_age_minutes: PENDING_AGE.in_minutes.to_i
          }
        )
      end

      def check_failed_webhook_backlog
        count = PaystackEvent.retryable.count
        return if count.zero?

        add_finding(
          kind: "webhook_backlog",
          severity: count >= 5 ? "critical" : "warning",
          title: "Failed Paystack webhooks need attention",
          body: "#{count} retryable webhook event(s) are still failed.",
          metadata: {
            audit_key: "platform:webhook_backlog",
            count: count
          }
        )
      end

      def check_paid_tips_against_paystack
        Tip.paid
           .where(paid_at: SETTLEMENT_LOOKBACK.ago..)
           .order(paid_at: :desc)
           .limit(TIP_VERIFY_LIMIT)
           .find_each do |tip|
          verification = @client.verify_transaction(tip.paystack_reference)
          next if verification.success? && verification.status == "success"

          add_finding(
            kind: "tip_payment_mismatch",
            severity: "critical",
            title: "Paid tip does not match Paystack",
            body: "Tip #{tip.paystack_reference} is paid locally but Paystack reports #{verification.status || 'unknown'}.",
            metadata: {
              audit_key: "tip:#{tip.id}:payment_mismatch",
              tip_id: tip.id,
              tribe_id: tip.tribe_id,
              paystack_reference: tip.paystack_reference,
              paystack_status: verification.status,
              paystack_message: verification.message
            }
          )
        end
      end

      def check_unsettled_paid_tips
        creators_for_batch.find_each do |tribe|
          settled_tip_ids = tribe.paystack_settlements.where.not(tip_id: nil).select(:tip_id)
          unsettled = tribe.tips.paid
            .where("paid_at < ?", UNSETTLED_GRACE.ago)
            .where.not(id: settled_tip_ids)
            .count
          next if unsettled.zero?

          add_finding(
            kind: "unsettled_paid_tip",
            severity: unsettled >= 3 ? "critical" : "warning",
            title: "Paid tips missing settlement records",
            body: "@#{tribe.username} has #{unsettled} paid tip(s) without a linked settlement.",
            metadata: {
              audit_key: "tribe:#{tribe.id}:unsettled_paid_tips",
              tribe_id: tribe.id,
              username: tribe.username,
              count: unsettled
            }
          )
        end
      end

      def check_settlement_status_drift
        response = @client.list_transfers(per_page: 50)
        return unless response.success?

        remote_by_code = Array(response.data).each_with_object({}) do |row, memo|
          data = row.is_a?(Hash) ? row.with_indifferent_access : {}
          code = data[:transfer_code].presence || data[:id].to_s
          memo[code] = data if code.present?
        end

        creators_for_batch.find_each do |tribe|
          tribe.paystack_settlements
            .where("paystack_transfer_code LIKE 'TRF_%'")
            .where.not(paystack_transfer_code: nil)
            .where("paystack_transfer_code NOT LIKE 'TRF_sim_%'")
            .where(updated_at: SETTLEMENT_LOOKBACK.ago..)
            .recent_first
            .limit(20)
            .find_each do |settlement|
            remote = remote_by_code[settlement.paystack_transfer_code]
            next if remote.blank?

            remote_status = remote[:status].to_s.downcase
            next if remote_status.blank?
            next if settlement.status == remote_status

            add_finding(
              kind: "settlement_status_drift",
              severity: "warning",
              title: "Settlement status drift",
              body: "Settlement #{settlement.paystack_transfer_code} is #{settlement.status} locally but #{remote_status} in Paystack.",
              metadata: {
                audit_key: "settlement:#{settlement.id}:status_drift",
                settlement_id: settlement.id,
                tribe_id: settlement.tribe_id,
                paystack_transfer_code: settlement.paystack_transfer_code,
                local_status: settlement.status,
                remote_status: remote_status
              }
            )
          end
        end
      end

      def check_onboarding_drift(tribe)
        return unless tribe.tips.paid.exists?

        report = AuditOnboarding.call(tribe, sync: false)
        return if report.healthy

        add_finding(
          kind: "onboarding_drift",
          severity: "warning",
          title: "Creator onboarding drift",
          body: "@#{tribe.username} has paid tips but Paystack onboarding checks are unhealthy.",
          metadata: {
            audit_key: "tribe:#{tribe.id}:onboarding_drift",
            tribe_id: tribe.id,
            username: tribe.username,
            failed_checks: report.checks.reject { |check| %i[ok skipped].include?(check.status) }.map(&:name)
          }
        )
      end

      def add_finding(kind:, severity:, title:, body:, metadata:)
        @findings << Finding.new(
          kind: kind,
          severity: severity,
          title: title,
          body: body,
          metadata: metadata.stringify_keys
        )
      end

      def record_alert!(finding)
        Tribetip::Audit::RecordPaymentAlert.call(
          kind: finding.kind,
          title: finding.title,
          body: finding.body,
          metadata: finding.metadata,
          severity: finding.severity
        )
      end

      def build_summary(findings)
        {
          findings_count: findings.length,
          critical_count: findings.count { |finding| finding.severity == "critical" },
          warning_count: findings.count { |finding| finding.severity == "warning" },
          creators_examined: CREATOR_BATCH_SIZE,
          tips_verified: @client.stub_mode? ? 0 : [ TIP_VERIFY_LIMIT, Tip.paid.count ].min
        }
      end

      def cache_report!(report)
        Tribetip::SecureCache.write(
          REPORT_CACHE_KEY,
          report.as_json,
          scope: :private,
          ttl: REPORT_CACHE_TTL
        )
      end

      def log_report!(report)
        Tribetip::Audit::PaymentLogger.log(
          event: "platform_reconciliation_completed",
          metadata: {
            auto_repair: report.auto_repair,
            repairs: report.repairs,
            summary: report.summary
          }
        )
      end
    end
  end
end
