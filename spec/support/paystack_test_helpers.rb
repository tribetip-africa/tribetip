# frozen_string_literal: true

module PaystackTestHelpers
  def complete_stub_paystack_onboarding!(tribe)
    market = Tribetip::Paystack::Market.for_tribe(tribe)
    Tribetip::Paystack::ProvisionSubaccount.call(
      tribe,
      settlement_bank: market.stub_settlement_bank,
      account_number: market.stub_account_number,
      business_name: tribe.username
    )
    tribe.reload
  end
end

RSpec.configure do |config|
  config.include PaystackTestHelpers
end
