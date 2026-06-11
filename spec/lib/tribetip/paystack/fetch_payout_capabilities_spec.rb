# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::FetchPayoutCapabilities do
  let(:client) { instance_double(Tribetip::Paystack::Client, stub_mode?: false) }

  around do |example|
    previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    example.run
  ensure
    Rails.cache = previous_cache
  end

  before do
    described_class.clear!
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
  end

  it "defaults to auto effective mode on starter business tier" do
    allow(ENV).to receive(:fetch).with("TRIBETIP_PAYOUT_MODE", "auto").and_return("manual")
    allow(ENV).to receive(:fetch).with("TRIBETIP_PAYSTACK_BUSINESS_TIER", "unknown").and_return("starter")

    capabilities = described_class.call(client: client)

    expect(capabilities.configured_payout_mode).to eq("manual")
    expect(capabilities.effective_payout_mode).to eq("auto")
    expect(capabilities.transfers_supported).to be(false)
    expect(capabilities.manual_withdrawals_enabled).to be(false)
    expect(capabilities.auto_settlement_active).to be(true)
    expect(capabilities.blocker).to include("Registered Business")
  end

  it "allows manual withdrawals when transfers are explicitly enabled" do
    allow(ENV).to receive(:fetch).with("TRIBETIP_PAYOUT_MODE", "auto").and_return("manual")
    allow(ENV).to receive(:[]).with("TRIBETIP_PAYSTACK_TRANSFERS_ENABLED").and_return("true")

    capabilities = described_class.call(client: client)

    expect(capabilities.effective_payout_mode).to eq("manual")
    expect(capabilities.manual_withdrawals_enabled).to be(true)
    expect(capabilities.blocker).to be_nil
  end

  it "caches transfer capability after a starter business failure" do
    described_class.record_transfer_outcome!(
      message: "You cannot initiate third party payouts as a starter business",
      success: false
    )

    allow(ENV).to receive(:fetch).with("TRIBETIP_PAYOUT_MODE", "auto").and_return("manual")

    capabilities = described_class.call(client: client)

    expect(capabilities.transfers_supported).to be(false)
    expect(capabilities.business_tier).to eq("starter")
  end
end
