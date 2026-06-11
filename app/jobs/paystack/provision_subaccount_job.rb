# frozen_string_literal: true

module Paystack
  class ProvisionSubaccountJob < ApplicationJob
    queue_as :paystack

    limits_concurrency to: 1, key: ->(tribe_id, *) { "paystack-subaccount/#{tribe_id}" }, duration: 10.minutes

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(tribe_id, settlement_bank:, account_number:, business_name: nil)
      tribe = Tribe.find_by(id: tribe_id)
      return unless tribe&.paystack_sync_required?

      run_job_step(tribe_id: tribe_id) do
        result = Tribetip::Paystack::ProvisionSubaccount.call(
          tribe,
          settlement_bank: settlement_bank,
          account_number: account_number,
          business_name: business_name
        )
        raise StandardError, result.message unless result.success?

        result
      end
    end
  end
end
