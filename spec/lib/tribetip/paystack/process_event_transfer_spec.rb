# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::ProcessEvent do
  it "records settlements for transfer.success webhooks" do
    tribe = create_onboarded_tribe(username: "process_event")
    event = {
      "event" => "transfer.success",
      "data" => {
        "transfer_code" => "TRF_process_event",
        "amount" => 80_000,
        "currency" => "KES",
        "status" => "success",
        "metadata" => {
          "tribe_id" => tribe.id,
          "subaccount_code" => tribe.paystack_subaccount_code
        },
        "recipient" => {
          "details" => {
            "account_number" => "0712345678",
            "bank_name" => "M-PESA"
          }
        }
      }
    }

    described_class.call(event)

    settlement = PaystackSettlement.find_by(paystack_transfer_code: "TRF_process_event")
    expect(settlement).to be_present
    expect(settlement.tribe_id).to eq(tribe.id)
    expect(settlement.status).to eq("success")
  end
end
