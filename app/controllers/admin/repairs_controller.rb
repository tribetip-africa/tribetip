# frozen_string_literal: true

module Admin
  class RepairsController < BaseController
    before_action :set_tribe

    def create
      authorize @tribe, :audit_paystack?

      unless @tribe.creator?
        return render_error(
          Tribetip::Errors::BadRequest.new("Paystack repair is only available for creator accounts.")
        )
      end

      apply_http_cache_policy(:no_store)
      result = Tribetip::Paystack::RepairCreatorPayments.call(@tribe)

      render json: {
        tribe_id: @tribe.id,
        username: @tribe.username,
        message: "Paystack data synced for @#{@tribe.username}.",
        repair: result.as_json
      }
    end

    private

    def set_tribe
      @tribe = Tribe.find(params[:id])
    end
  end
end
