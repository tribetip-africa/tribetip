# frozen_string_literal: true

module TribeSerializable
  extend ActiveSupport::Concern

  private

  def tribe_json(tribe)
    {
      id: tribe.id,
      email: tribe.email,
      username: tribe.username,
      role: tribe.role,
      account_status: tribe.account_status,
      paystack_onboarding: paystack_onboarding_json(tribe)
    }
  end

  def paystack_onboarding_json(tribe, refresh_payout: false)
    payout = Tribetip::Paystack::FetchPayoutStatus.call(tribe, refresh: refresh_payout)

    {
      customer_ready: tribe.paystack_customer_ready?,
      subaccount_ready: tribe.paystack_subaccount_ready?,
      complete: tribe.paystack_onboarding_complete?,
      subaccount_verified: payout.subaccount_verified,
      market: tribe.paystack_market.as_json,
      provisioning_error: tribe.paystack_provisioning_error,
      payout: payout.as_json
    }.compact
  end

  def owner_profile_json(tribe)
    payout = Tribetip::Paystack::FetchPayoutStatus.call(tribe, refresh: true)
    metrics = Tribetip::Metrics::CreatorSummary.call(tribe)

    tribe_json(tribe).merge(
      display_name: tribe.display_name,
      bio: tribe.bio,
      country_code: tribe.country_code,
      currency: tribe.currency,
      default_tip_amount_cents: tribe.default_tip_amount_cents,
      is_profile_public: tribe.is_profile_public,
      metrics: metrics.as_json.merge(
        pending_settlement_cents: payout.pending_settlement_cents,
        subaccount_verified: payout.subaccount_verified
      )
    )
  end
end
