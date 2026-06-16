# frozen_string_literal: true

module Paystack
  class ReconcilePlatformJob < ApplicationJob
    queue_as :default

    def perform(auto_repair: true)
      Tribetip::Paystack::ReconcilePlatform.call(auto_repair: auto_repair)
    end
  end
end
