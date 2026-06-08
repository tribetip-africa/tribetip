# frozen_string_literal: true

module TipSerializable
  extend ActiveSupport::Concern

  private

  def tip_json(tip, include_checkout: false)
    payload = {
      id: tip.id,
      tribe_id: tip.tribe_id,
      amount_cents: tip.amount_cents,
      currency: tip.currency,
      status: tip.status,
      paystack_reference: tip.paystack_reference,
      supporter_email: tip.supporter_email,
      supporter_name: tip.supporter_name,
      message: tip.message,
      paid_at: tip.paid_at,
      paid_via: tip.paid_via,
      failed_reason: tip.failed_reason,
      created_at: tip.created_at
    }

    if include_checkout
      payload[:authorization_url] = tip.paystack_metadata["authorization_url"]
      payload[:checkout_status] = tip.paystack_metadata["checkout_status"]
    end

    payload
  end
end
