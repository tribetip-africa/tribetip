# frozen_string_literal: true

module Paystack
  class ProvisionCustomerJob < ApplicationJob
    queue_as :paystack

    limits_concurrency to: 1, key: ->(tribe_id) { "paystack-customer/#{tribe_id}" }, duration: 10.minutes

    def perform(tribe_id)
      tribe = Tribe.find_by(id: tribe_id)
      return unless tribe&.paystack_sync_required?

      run_job_step(tribe_id: tribe_id) do
        result = Tribetip::Paystack::ProvisionCustomer.call(tribe)
        raise StandardError, result.message unless result.success?

        result
      end
    end
  end
end
