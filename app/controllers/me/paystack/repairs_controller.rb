# frozen_string_literal: true

module Me
  module Paystack
    class RepairsController < ApplicationController
      before_action :authenticate_tribe!
      before_action :ensure_creator_for_paystack!

      def create
        apply_http_cache_policy(:no_store)
        result = Tribetip::Paystack::RepairCreatorPayments.call(current_tribe)

        render json: {
          message: "Paystack data synced.",
          repair: result.as_json
        }
      end

      private

      def ensure_creator_for_paystack!
        return if current_tribe.creator?

        render_error(
          Tribetip::Errors::BadRequest.new("Paystack repair is not available for admin accounts.")
        )
      end
    end
  end
end
