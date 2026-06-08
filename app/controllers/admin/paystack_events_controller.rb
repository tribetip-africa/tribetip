# frozen_string_literal: true

module Admin
  class PaystackEventsController < BaseController
    def index
      apply_http_cache_policy(:no_store)

      events = PaystackEvent.recent_first
      events = events.where(status: params[:status]) if params[:status].present?

      render json: {
        events: events.limit(page_limit).offset(page_offset).map { |event| event_json(event) },
        pagination: {
          limit: page_limit,
          offset: page_offset,
          total: events.count
        }
      }
    end

    def replay
      apply_http_cache_policy(:no_store)

      event = PaystackEvent.find(params[:id])
      unless event.replayable?
        return render_error(
          Tribetip::Errors::BadRequest.new("Only failed webhook events can be replayed.")
        )
      end

      event.replay!
      record_admin_audit!(
        action: "replay_paystack_event",
        target: event,
        details: {
          paystack_reference: event.payload.dig("data", "reference"),
          event_type: event.event_type
        }
      )

      render json: {
        message: "Webhook event queued for replay.",
        event: event_json(event.reload)
      }
    end

    private

    def page_limit
      [ [ params.fetch(:limit, 25).to_i, 1 ].max, 100 ].min
    end

    def page_offset
      [ params.fetch(:offset, 0).to_i, 0 ].max
    end

    def event_json(event)
      {
        id: event.id,
        event_id: event.event_id,
        event_type: event.event_type,
        status: event.status,
        error_message: event.error_message,
        processed_at: event.processed_at,
        created_at: event.created_at,
        paystack_reference: event.payload.dig("data", "reference"),
        tip_id: event.tip_id
      }
    end
  end
end
