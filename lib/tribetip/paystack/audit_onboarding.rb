# frozen_string_literal: true

module Tribetip
  module Paystack
    class AuditOnboarding
      Check = Struct.new(:name, :status, :message, keyword_init: true) do
        def as_json(*)
          {
            name: name,
            status: status.to_s,
            message: message
          }
        end
      end

      Report = Struct.new(
        :username,
        :market,
        :local,
        :remote,
        :checks,
        :customer_ready,
        :subaccount_ready,
        :onboarding_complete,
        :healthy,
        keyword_init: true
      ) do
        def as_json(*)
          {
            username: username,
            market: market.as_json,
            local: local,
            remote: remote,
            checks: checks.map(&:as_json),
            customer_ready: customer_ready,
            subaccount_ready: subaccount_ready,
            onboarding_complete: onboarding_complete,
            healthy: healthy
          }
        end
      end

      VERIFY_CACHE_TTL = 10.minutes

      def self.call(tribe, sync: false)
        new(tribe).call(sync: sync)
      end

      def initialize(tribe)
        @tribe = tribe
        @client = Client.new
        @market = Market.for_tribe(@tribe)
      end

      def call(sync: false)
        customer_remote = remote_verify(@tribe.paystack_customer_code, refresh: sync) do |code|
          @client.fetch_customer(code)
        end
        subaccount_remote = remote_verify(@tribe.paystack_subaccount_code, refresh: sync) do |code|
          @client.fetch_subaccount(code)
        end

        checks = build_checks(customer_remote, subaccount_remote)
        customer_ready = customer_remote[:verified]
        subaccount_ready = subaccount_remote[:verified]

        sync_onboarding_state!(customer_ready, subaccount_ready) if sync

        Report.new(
          username: @tribe.username,
          market: @market,
          local: local_state,
          remote: {
            customer: customer_remote,
            subaccount: subaccount_remote
          },
          checks: checks,
          customer_ready: customer_ready,
          subaccount_ready: subaccount_ready,
          onboarding_complete: @tribe.reload.paystack_onboarding_complete?,
          healthy: healthy?(checks)
        )
      end

      private

      def local_state
        {
          customer_code: @tribe.paystack_customer_code,
          subaccount_code: @tribe.paystack_subaccount_code,
          onboarding_completed_at: @tribe.onboarding_completed_at
        }
      end

      def remote_verify(code, refresh: false)
        if code.blank?
          return { code: nil, verified: false, message: "No code stored" }
        end

        cache_key = "paystack_verify/#{code}"
        fetch_result = lambda do |*_args|
          response = yield(code)
          verified = if subaccount_response?(code)
            subaccount_verified?(response)
          else
            response.success?
          end
          {
            verified: verified,
            message: verification_message(response, verified)
          }
        end

        payload = if refresh
          result = fetch_result.call
          Tribetip::SecureCache.write(cache_key, result, scope: :public, ttl: VERIFY_CACHE_TTL)
          result
        else
          Tribetip::SecureCache.fetch(cache_key, scope: :public, ttl: VERIFY_CACHE_TTL, &fetch_result)
        end

        {
          code: code,
          verified: payload[:verified] == true || payload["verified"] == true,
          message: payload[:message] || payload["message"]
        }
      end

      def build_checks(customer_remote, subaccount_remote)
        checks = []

        if @market.subaccount_supported?
          checks << check(
            "customer_code_present",
            @tribe.paystack_customer_code.present? ? :ok : :missing,
            customer_code_message
          )
          checks << check(
            "customer_paystack_verified",
            customer_remote[:verified] ? :ok : :failed,
            verified_message(customer_remote, "Paystack customer")
          )
        else
          checks << check(
            "customer_paystack_required",
            :skipped,
            "Paystack customer is not required for #{@market.name}"
          )
          if @tribe.paystack_customer_code.present?
            checks << check(
              "customer_code_optional",
              :skipped,
              "Paystack customer may exist but payouts are not supported for #{@market.name}"
            )
          end
        end

        if @market.subaccount_supported?
          checks << check(
            "subaccount_code_present",
            @tribe.paystack_subaccount_code.present? ? :ok : :missing,
            subaccount_code_message
          )
          checks << check(
            "subaccount_paystack_verified",
            subaccount_remote[:verified] ? :ok : :failed,
            verified_message(subaccount_remote, "Paystack subaccount")
          )
        else
          checks << check(
            "subaccount_region_supported",
            :skipped,
            "Subaccounts are not supported for #{@market.name}"
          )
          if @tribe.paystack_subaccount_code.present?
            checks << check(
              "subaccount_code_absent",
              :failed,
              "Unexpected subaccount code for unsupported market"
            )
          end
        end

        expected_complete = expected_onboarding_complete?(customer_remote, subaccount_remote)
        actual_complete = @tribe.onboarding_completed_at.present?
        checks << check(
          "onboarding_complete",
          expected_complete == actual_complete ? :ok : :failed,
          onboarding_complete_message(expected_complete, actual_complete)
        )

        checks
      end

      def check(name, status, message)
        Check.new(name: name, status: status, message: message)
      end

      def verified_message(remote, label)
        if remote[:verified]
          remote[:message].presence || "#{label} verified in Paystack"
        else
          remote[:message].presence || "#{label} could not be verified"
        end
      end

      def customer_code_message
        if @tribe.paystack_customer_code.present?
          "Paystack customer code is stored"
        else
          "Paystack customer code is missing"
        end
      end

      def subaccount_code_message
        if @tribe.paystack_subaccount_code.present?
          "Paystack subaccount code is stored"
        else
          "Paystack subaccount code is missing"
        end
      end

      def onboarding_complete_message(expected_complete, actual_complete)
        if expected_complete == actual_complete
          if actual_complete
            "Onboarding completion timestamp matches Paystack verification"
          else
            "Onboarding correctly remains incomplete"
          end
        elsif expected_complete
          "Onboarding should be complete but onboarding_completed_at is blank"
        else
          "Onboarding should be incomplete but onboarding_completed_at is set"
        end
      end

      def expected_onboarding_complete?(customer_remote, subaccount_remote)
        return false unless customer_remote[:verified]

        if @market.subaccount_supported?
          subaccount_remote[:verified]
        else
          false
        end
      end

      def healthy?(checks)
        checks.all? { |entry| %i[ok skipped].include?(entry.status) }
      end

      def sync_onboarding_state!(customer_ready, subaccount_ready)
        if customer_ready && subaccount_ready
          @tribe.mark_paystack_onboarding_complete!
        elsif @tribe.onboarding_completed_at.present?
          @tribe.update!(onboarding_completed_at: nil)
        end
      end

      def subaccount_response?(code)
        code.to_s.start_with?("ACCT_", "acct_")
      end

      def subaccount_verified?(response)
        return response.success? if @client.stub_mode?

        data = response.data
        response.success? && data.is_a?(Hash) && data["is_verified"] == true
      end

      def verification_message(response, verified)
        if verified
          subaccount_data = response.data.is_a?(Hash) ? response.data : {}
          if subaccount_data["is_verified"] == true
            "Subaccount verified in Paystack"
          else
            response.message.presence || "Verified in Paystack"
          end
        elsif response.data.is_a?(Hash) && response.data["is_verified"] == false
          "Paystack has not verified this payout account yet"
        else
          response.message.presence || "Could not verify in Paystack"
        end
      end
    end
  end
end
