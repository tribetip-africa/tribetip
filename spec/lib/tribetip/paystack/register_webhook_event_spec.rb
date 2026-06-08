# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::RegisterWebhookEvent do
  it "registers a webhook event with a stable id" do
    payload = { "event" => "charge.success", "data" => { "reference" => "tip_abc", "id" => 42 } }

    result = described_class.call(payload)

    expect(result.duplicate).to be(false)
    expect(result.event.event_id).to eq("paystack:charge.success:42")
    expect(result.event.status).to eq("pending")
  end

  it "returns duplicate events without creating a second row" do
    payload = { "event" => "charge.success", "data" => { "reference" => "tip_dup" } }

    first = described_class.call(payload)
    second = described_class.call(payload)

    expect(first.duplicate).to be(false)
    expect(second.duplicate).to be(true)
    expect(second.event.id).to eq(first.event.id)
    expect(PaystackEvent.count).to eq(1)
  end
end
