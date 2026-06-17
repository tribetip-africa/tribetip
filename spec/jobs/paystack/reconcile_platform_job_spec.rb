# frozen_string_literal: true

require "rails_helper"

RSpec.describe Paystack::ReconcilePlatformJob, type: :job do
  it "runs the platform reconciliation service" do
    allow(Tribetip::Paystack::ReconcilePlatform).to receive(:call).with(auto_repair: true)

    described_class.perform_now

    expect(Tribetip::Paystack::ReconcilePlatform).to have_received(:call).with(auto_repair: true)
  end
end
