# frozen_string_literal: true

module Me
  module Paystack
    class RepairsController < ApplicationController
      before_action :authenticate_tribe!
      before_action :authorize_paystack_repair!

      def create
        apply_http_cache_policy(:no_store)
        result = Tribetip::Paystack::RepairCreatorPayments.call(current_tribe)

        render json: {
          message: "Paystack data synced.",
          repair: result.as_json
        }
      end

      private

      def authorize_paystack_repair!
        authorize current_tribe, :access_paystack_repair?
      end
    end
  end
end
