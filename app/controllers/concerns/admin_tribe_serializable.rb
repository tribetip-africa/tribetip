# frozen_string_literal: true

module AdminTribeSerializable
  extend ActiveSupport::Concern

  private

  def admin_tribe_json(tribe, tip_stats: {})
    stats = tip_stats[tribe.id] || {}

    {
      id: tribe.id,
      username: tribe.username,
      email: tribe.email,
      role: tribe.role,
      account_status: tribe.account_status,
      is_profile_public: tribe.is_profile_public,
      paystack_onboarding_complete: tribe.paystack_onboarding_complete?,
      paystack_customer_ready: tribe.paystack_customer_ready?,
      paystack_subaccount_ready: tribe.paystack_subaccount_ready?,
      paid_tips_count: stats[:paid_tips_count] || 0,
      pending_tips_count: stats[:pending_tips_count] || 0,
      total_earned_cents: stats[:total_earned_cents] || 0,
      pending_tips_cents: stats[:pending_tips_cents] || 0,
      currency: tribe.currency,
      created_at: tribe.created_at
    }
  end

  def admin_overview_json
    Tribetip::Metrics::PlatformOverview.call
  end
end
