# frozen_string_literal: true

module Tribetip
  module Metrics
    class PlatformOverview
      def self.call
        new.call
      end

      def call
        tribe_counts
          .merge(tip_counts)
          .merge(payout_counts)
          .merge(recent_tip_counts)
          .merge(ops_counts)
      end

      private

      def tribe_counts
        {
          total_tribes: Tribe.count,
          active_tribes: Tribe.where(account_status: "active").count,
          suspended_tribes: Tribe.where(account_status: "suspended").count,
          pending_tribes: Tribe.where(account_status: "pending").count,
          published_profiles: Tribe.where(is_profile_public: true).count,
          admins: Tribe.where(role: "admin").count,
          creators: Tribe.where(role: "creator").count
        }
      end

      def tip_counts
        {
          total_tips: Tip.count,
          paid_tips: Tip.paid.count,
          pending_tips: Tip.where(status: "pending").count,
          failed_tips: Tip.where(status: "failed").count,
          paid_volume_cents: volume_by_currency(Tip.paid),
          pending_volume_cents: volume_by_currency(Tip.where(status: "pending"))
        }
      end

      def payout_counts
        {
          onboarding_complete: Tribe.where.not(onboarding_completed_at: nil).count,
          payout_linked: Tribe.where.not(paystack_subaccount_code: nil).count,
          payout_customers: Tribe.where.not(paystack_customer_code: nil).count
        }
      end

      def recent_tip_counts
        recent = Tip.paid.where("paid_at >= ?", 30.days.ago)

        {
          tips_last_30_days: recent.count,
          volume_last_30_days_cents: volume_by_currency(recent)
        }
      end

      def volume_by_currency(scope)
        scope.group(:currency).sum(:amount_cents).transform_values(&:to_i)
      end

      def ops_counts
        {
          unresolved_payment_alerts: PaymentAlert.unresolved.count,
          failed_webhooks: PaystackEvent.failed.count,
          reconciliation: reconciliation_summary
        }
      end

      def reconciliation_summary
        report = Tribetip::SecureCache.read(
          Tribetip::Paystack::ReconcilePlatform::REPORT_CACHE_KEY,
          scope: :private
        )
        return { never_run: true } if report.blank?

        summary = report["summary"] || report[:summary] || {}
        {
          never_run: false,
          checked_at: report["checked_at"] || report[:checked_at],
          findings_count: summary["findings_count"] || summary[:findings_count] || 0,
          critical_count: summary["critical_count"] || summary[:critical_count] || 0,
          warning_count: summary["warning_count"] || summary[:warning_count] || 0
        }
      end
    end
  end
end
