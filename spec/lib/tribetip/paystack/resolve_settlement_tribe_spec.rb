# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::ResolveSettlementTribe do
  def create_tribe(username:)
    tribe = Tribe.create!(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      country_code: "KE",
      currency: "KES"
    )
    complete_stub_paystack_onboarding!(tribe)
    tribe.reload
  end

  it "resolves a tribe when tribe_id and subaccount_code agree" do
    tribe = create_tribe(username: "resolve_match")

    result = described_class.call(
      metadata: {
        tribe_id: tribe.id,
        subaccount_code: tribe.paystack_subaccount_code
      }
    )

    expect(result).to be_accepted
    expect(result.tribe.id).to eq(tribe.id)
  end

  it "rejects when tribe_id and subaccount_code point to different tribes" do
    tribe_a = create_tribe(username: "resolve_a")
    tribe_b = create_tribe(username: "resolve_b")

    result = nil
    expect do
      result = described_class.call(
        transfer_code: "TRF_resolve_conflict",
        metadata: {
          tribe_id: tribe_a.id,
          subaccount_code: tribe_b.paystack_subaccount_code
        }
      )
    end.to change(PaymentAlert, :count).by(1)

    expect(result).not_to be_accepted
    expect(result.rejected_reason).to eq("tribe_id_subaccount_conflict")
    expect(PaymentAlert.last.kind).to eq("settlement_tribe_rejected")
  end

  it "rejects when subaccount_code does not match the resolved tribe" do
    tribe = create_tribe(username: "resolve_subaccount")

    result = described_class.call(
      metadata: {
        tribe_id: tribe.id,
        subaccount_code: "ACCT_wrong_code"
      }
    )

    expect(result).not_to be_accepted
    expect(result.rejected_reason).to eq("subaccount_mismatch")
  end

  it "resolves by subaccount_code when tribe_id is absent" do
    tribe = create_tribe(username: "resolve_subaccount_only")

    result = described_class.call(
      metadata: {
        subaccount_code: tribe.paystack_subaccount_code
      }
    )

    expect(result).to be_accepted
    expect(result.tribe.id).to eq(tribe.id)
  end
end
