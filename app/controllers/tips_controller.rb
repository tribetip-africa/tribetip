# frozen_string_literal: true

class TipsController < ApplicationController
  include TipSerializable
  include Tippable
  include Idempotable
  include AuditRequestContext

  CHECKOUT_WAIT = 25.seconds

  def create
    apply_http_cache_policy(:no_store)

    return if idempotency_key_header.present? && replay_idempotent_tip_checkout

    tribe = find_tippable_tribe!(tip_params[:username])
    market = Tribetip::Paystack::Market.for_tribe(tribe)
    reference = Tip.generate_reference
    amount_cents = tip_params[:amount_cents].to_i
    currency = tip_params[:currency].presence || tribe.currency

    tip = tribe.tips.build(
      amount_cents: amount_cents,
      currency: currency,
      paystack_reference: reference,
      supporter_email: tip_params[:supporter_email],
      supporter_name: tip_params[:supporter_name],
      message: tip_params[:message],
      paystack_metadata: { "checkout_status" => "processing" }
    )

    unless tip.save
      return render_error(
        Tribetip::Errors::Validation.new(
          "Validation failed.",
          details: { errors: tip.errors.full_messages }
        )
      )
    end

    tip.record_created_event!(request_context: audit_request_context)

    ::Paystack::InitializeTipCheckoutJob.perform_later(tip.id)
    tip = wait_for_checkout!(tip)

    if checkout_ready?(tip)
      render_checkout_response(tip, status: :created)
    else
      render_checkout_response(tip, status: :accepted)
    end
  end

  def checkout
    apply_http_cache_policy(:no_store)

    tip = Tip.find_by!(paystack_reference: params[:paystack_reference])
    reconcile_tip!(tip)
    render json: { tip: tip_json(tip.reload, include_checkout: true) }, status: :ok
  end

  def reconcile
    apply_http_cache_policy(:no_store)

    tip = Tip.find_by!(paystack_reference: params[:paystack_reference])
    result = reconcile_tip!(tip)

    if result.success?
      render json: { message: "Tip payment reconciled.", tip: tip_json(tip.reload) }, status: :ok
    else
      render json: { message: result.message, tip: tip_json(tip.reload) }, status: :accepted
    end
  end

  private

  def replay_idempotent_tip_checkout
    cached = IdempotencyKey.find_active(scope: "tip_checkout", key: idempotency_key_header)
    return false unless cached

    render json: cached.response_body, status: cached.response_code
    true
  end

  def wait_for_checkout!(tip)
    Tribetip::AsyncPoll.wait_until(max: CHECKOUT_WAIT) do
      tip.reload
      checkout_ready?(tip) || checkout_failed?(tip) ? tip : nil
    end || tip.reload
  end

  def checkout_ready?(tip)
    tip.paystack_metadata["authorization_url"].present?
  end

  def checkout_failed?(tip)
    tip.paystack_metadata["checkout_status"] == "failed"
  end

  def render_checkout_response(tip, status:)
    body = {
      message: status == :created ? "Tip checkout initialized." : "Tip checkout is still processing.",
      tip: tip_json(tip, include_checkout: true)
    }

    if idempotency_key_header.present?
      IdempotencyKey.store!(
        scope: "tip_checkout",
        key: idempotency_key_header,
        response_code: Rack::Utils.status_code(status),
        response_body: body
      )
    end

    if checkout_failed?(tip)
      message = tip.paystack_metadata["checkout_error"] || "Unable to initialize Paystack checkout."
      Tribetip::Audit::RecordTipEvent.call(
        tip: tip,
        action: "checkout_failed",
        from_status: tip.status,
        to_status: tip.status,
        source: "public",
        failed_reason: message,
        request_context: audit_request_context,
        metadata: tip.paystack_metadata
      )
      tip.destroy!
      return render_error(Tribetip::Errors::BadRequest.new(message))
    end

    render json: body, status: status
  end

  def reconcile_tip!(tip)
    Tribetip::Paystack::ReconcileTipPayment.call(
      tip,
      request_context: audit_request_context
    )
  rescue Tribetip::Errors::Base => error
    Tribetip::Paystack::ReconcileTipPayment::Result.new(success?: false, message: error.message)
  end

  def tip_params
    params.require(:tip).permit(
      :username,
      :amount_cents,
      :currency,
      :supporter_email,
      :supporter_name,
      :message
    )
  end
end
