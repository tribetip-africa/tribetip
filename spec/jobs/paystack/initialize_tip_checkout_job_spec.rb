# frozen_string_literal: true

require "rails_helper"

RSpec.describe Paystack::InitializeTipCheckoutJob, type: :job do
  include ActiveJob::TestHelper

  def create_tip(reference: "tip_checkout_job")
    tribe = Tribe.create!(
      email: "checkout_job@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "checkout_job_creator",
      display_name: "Checkout Job Creator",
      account_status: "active",
      is_profile_public: true
    )
    complete_stub_paystack_onboarding!(tribe)
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "pending",
      paystack_reference: reference,
      supporter_email: "fan@tribetip.africa",
      paystack_metadata: { "checkout_status" => "processing" }
    )
  end

  it "does not mark checkout failed when Paystack rate limits" do
    tip = create_tip
    client = instance_double(Tribetip::Paystack::Client)
    allow(Tribetip::Paystack::Client).to receive(:new).and_return(client)
    allow(client).to receive(:initialize_transaction).and_raise(
      Tribetip::Paystack::RateLimited, "Rate limit exceeded!"
    )

    expect { described_class.new.perform(tip.id) }.to raise_error(Tribetip::Paystack::RateLimited)

    expect(tip.reload.paystack_metadata["checkout_status"]).to eq("processing")
  end
end
