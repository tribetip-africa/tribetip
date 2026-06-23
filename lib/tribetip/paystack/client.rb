# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "cgi"

module Tribetip
  module Paystack
    class Client
      CHECKOUT_BASE_URL = "https://checkout.paystack.com"
      API_BASE_URL = "https://api.paystack.co"

      Response = Struct.new(:success?, :reference, :access_code, :authorization_url, :message, keyword_init: true)
      ResourceResponse = Struct.new(:success?, :code, :message, :data, keyword_init: true)
      VerifyResponse = Struct.new(:success?, :status, :subaccount_code, :message, :data, keyword_init: true)
      TransferResponse = Struct.new(:success?, :transfer_code, :status, :message, :data, keyword_init: true)

      def initialize(secret_key: ENV["PAYSTACK_SECRET_KEY"])
        @secret_key = secret_key.to_s
      end

      def stub_mode?
        @secret_key.blank?
      end

      # Local dev: keep real Paystack for tips/checkout but stub transfer API calls.
      def simulate_transfers?
        ActiveModel::Type::Boolean.new.cast(ENV["TRIBETIP_SIMULATE_TRANSFERS"])
      end

      def create_customer(email:, first_name:, metadata: {})
        return stub_resource("cus") if stub_mode?

        response = post("/customer", {
          email: email,
          first_name: first_name,
          metadata: metadata
        })

        resource_response(response, code_path: %w[customer_code])
      end

      def list_banks(paystack_bank_country:)
        return stub_list_banks(paystack_bank_country) if stub_mode?

        response = get("/bank?country=#{CGI.escape(paystack_bank_country)}")
        banks = response.fetch("data", [])

        ResourceResponse.new(
          success?: response["status"] == true,
          code: nil,
          message: response["message"],
          data: banks
        )
      end

      def fetch_customer(code)
        return ResourceResponse.new(success?: code.present?) if stub_mode?

        response = get("/customer/#{code}")
        resource_response(response, code_path: %w[customer_code], fallback_code: code)
      end

      def create_subaccount(business_name:, settlement_bank:, account_number:, percentage_charge:, primary_contact_email:, currency:, metadata: {}, settlement_schedule: nil)
        return stub_resource("acct") if stub_mode?

        body = {
          business_name: business_name,
          settlement_bank: settlement_bank,
          account_number: account_number,
          percentage_charge: percentage_charge,
          primary_contact_email: primary_contact_email,
          currency: currency,
          metadata: metadata
        }
        body[:settlement_schedule] = settlement_schedule if settlement_schedule.present?

        response = post("/subaccount", body)

        resource_response(response, code_path: %w[subaccount_code])
      end

      def fetch_subaccount(code)
        return stub_subaccount(code) if stub_mode?

        response = get("/subaccount/#{code}")
        resource_response(response, code_path: %w[subaccount_code], fallback_code: code)
      end

      def fetch_transaction_totals(subaccount: nil)
        return stub_transaction_totals if stub_mode?

        query = subaccount.present? ? "?subaccount=#{CGI.escape(subaccount.to_s)}" : ""
        response = get("/transaction/totals#{query}")
        data = response.fetch("data", {})

        ResourceResponse.new(
          success?: response["status"] == true,
          code: subaccount,
          message: response["message"],
          data: data.presence
        )
      end

      def list_transfers(page: 1, per_page: 50)
        return stub_list_transfers if stub_mode?

        response = get("/transfer?page=#{page}&perPage=#{per_page}")
        transfers = response.fetch("data", [])

        ResourceResponse.new(
          success?: response["status"] == true,
          code: nil,
          message: response["message"],
          data: transfers
        )
      end

      def initiate_subaccount_withdrawal(subaccount:, amount_cents:, currency:, reference:, reason:, metadata: {})
        if stub_mode? || simulate_transfers?
          return stub_initiate_transfer(reference: reference, amount_cents: amount_cents, currency: currency)
        end

        response = post("/transfer", {
          source: "balance",
          amount: amount_cents,
          reference: reference,
          reason: reason,
          currency: currency,
          metadata: metadata.merge(subaccount_code: subaccount)
        })

        data = response.fetch("data", {})
        status = Tribetip::Paystack::SettlementRecord::STATUSES.include?(data["status"].to_s.downcase) ?
                   data["status"].to_s.downcase : "processing"

        TransferResponse.new(
          success?: response["status"] == true && data["transfer_code"].present?,
          transfer_code: data["transfer_code"],
          status: status,
          message: response["message"],
          data: data.presence
        )
      end

      def initialize_transaction(email:, amount_cents:, currency:, reference:, callback_url:, metadata: {}, subaccount: nil)
        return stub_initialize(reference) if stub_mode?

        body = {
          email: email,
          amount: amount_cents,
          currency: currency,
          reference: reference,
          callback_url: callback_url,
          metadata: metadata
        }
        body[:subaccount] = subaccount if subaccount.present?

        response = post("/transaction/initialize", body)
        data = response.fetch("data", {})

        Response.new(
          success?: response["status"] == true,
          reference: data["reference"] || reference,
          access_code: data["access_code"],
          authorization_url: data["authorization_url"],
          message: response["message"]
        )
      end

      def verify_transaction(reference)
        return VerifyResponse.new(success?: true, status: "success", subaccount_code: nil) if stub_mode?

        response = get("/transaction/verify/#{CGI.escape(reference.to_s)}")
        data = response.fetch("data", {})

        VerifyResponse.new(
          success?: response["status"] == true,
          status: data["status"],
          subaccount_code: extract_subaccount_code(data),
          message: response["message"],
          data: data.presence
        )
      end

      def verify_webhook_signature(payload_body, signature)
        return signature.present? if stub_mode? && Rails.env.test?

        return false if signature.blank? || @secret_key.blank?

        digest = OpenSSL::HMAC.hexdigest("SHA512", @secret_key, payload_body)
        ActiveSupport::SecurityUtils.secure_compare(digest, signature)
      end

      INLINE_RETRY_ATTEMPTS = ENV.fetch("TRIBETIP_PAYSTACK_INLINE_RETRY_ATTEMPTS", 4).to_i
      INLINE_RETRY_BASE_SECONDS = ENV.fetch("TRIBETIP_PAYSTACK_INLINE_RETRY_BASE_SECONDS", 0.25).to_f
      INLINE_RETRY_MAX_SECONDS = ENV.fetch("TRIBETIP_PAYSTACK_INLINE_RETRY_MAX_SECONDS", 5).to_f

      def self.rate_limited_response?(response, parsed = response)
        return rate_limited_message?(response) unless parsed.is_a?(Hash)

        status = parsed["_http_status"] || response.try(:code).to_i
        status == 429 || rate_limited_message?(parsed["message"])
      end

      def self.rate_limited_message?(message)
        message.to_s.match?(/rate limit/i)
      end

      private

      def stub_resource(prefix)
        code = "#{prefix}_stub_#{SecureRandom.hex(6)}"
        ResourceResponse.new(success?: true, code: code, message: "Stub Paystack resource", data: nil)
      end

      def stub_subaccount(code)
        ResourceResponse.new(
          success?: code.present?,
          code: code,
          message: "Stub Paystack subaccount",
          data: {
            "subaccount_code" => code,
            "is_verified" => true,
            "active" => true,
            "settlement_bank" => "MPESA",
            "account_number" => "0712345678",
            "settlement_schedule" => PayoutMode.settlement_schedule(
              transfers_supported: FetchPayoutCapabilities.call(client: self).transfers_supported
            ),
            "currency" => "KES"
          }
        )
      end

      def stub_transaction_totals
        ResourceResponse.new(
          success?: true,
          code: nil,
          message: "Stub transaction totals",
          data: {
            "total_transactions" => 0,
            "total_volume" => 0,
            "pending_transfers" => 0
          }
        )
      end

      def stub_list_transfers
        ResourceResponse.new(
          success?: true,
          code: nil,
          message: "Stub transfer list",
          data: []
        )
      end

      def stub_initiate_transfer(reference:, amount_cents:, currency:)
        TransferResponse.new(
          success?: true,
          transfer_code: "TRF_#{reference}",
          status: "processing",
          message: "Stub transfer initiated",
          data: {
            "transfer_code" => "TRF_#{reference}",
            "amount" => amount_cents,
            "currency" => currency,
            "status" => "processing",
            "reference" => reference
          }
        )
      end

      def stub_list_banks(paystack_bank_country)
        market = Market::MARKETS.values.find { |config| config[:paystack_bank_country] == paystack_bank_country }
        bank_name = market&.dig(:stub_bank_name) || "Stub Bank"
        bank_code = market&.dig(:stub_settlement_bank) || "000"

        banks = [
          {
            "name" => bank_name,
            "code" => bank_code,
            "country" => paystack_bank_country,
            "currency" => market&.dig(:currency),
            "type" => "kepss"
          }
        ]
        case paystack_bank_country
        when "kenya"
          banks << {
            "name" => "M-PESA",
            "code" => "MPESA",
            "country" => paystack_bank_country,
            "currency" => "KES",
            "type" => "mobile_money"
          }
        when "ghana"
          banks << {
            "name" => "MTN Mobile Money",
            "code" => "MTN",
            "country" => paystack_bank_country,
            "currency" => "GHS",
            "type" => "mobile_money"
          }
        end

        ResourceResponse.new(
          success?: true,
          code: nil,
          message: "Stub bank list",
          data: banks
        )
      end

      def extract_subaccount_code(data)
        subaccount = data["subaccount"]
        case subaccount
        when String
          subaccount
        when Hash
          subaccount["subaccount_code"] || subaccount["code"]
        end
      end

      def stub_initialize(reference)
        Response.new(
          success?: true,
          reference: reference,
          access_code: "stub_#{reference}",
          authorization_url: "#{CHECKOUT_BASE_URL}/#{reference}",
          message: "Stub Paystack checkout"
        )
      end

      def resource_response(response, code_path:, fallback_code: nil)
        data = response["data"] || {}
        code = code_path.reduce(data) { |memo, key| memo.is_a?(Hash) ? memo[key] : nil }
        code ||= fallback_code

        ResourceResponse.new(
          success?: response["status"] == true && code.present?,
          code: code,
          message: response["message"],
          data: data.presence
        )
      end

      def get(path)
        request_json(Net::HTTP::Get, path)
      end

      def post(path, body)
        request_json(Net::HTTP::Post, path, body)
      end

      def request_json(request_class, path, body = nil)
        attempt = 0

        loop do
          response = perform_http_request(request_class, path, body)
          parsed = parse_response_body(response)

          if self.class.rate_limited_response?(response, parsed)
            attempt += 1
            if attempt > INLINE_RETRY_ATTEMPTS
              raise RateLimited, parsed["message"] || "Paystack rate limit exceeded."
            end

            sleep(inline_retry_delay(attempt))
            next
          end

          return parsed
        end
      rescue JSON::ParserError
        { "status" => false, "message" => "Invalid Paystack response" }
      rescue RateLimited
        raise
      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, OpenSSL::SSLError => error
        { "status" => false, "message" => "Paystack is unreachable (#{error.class.name}). Check network connectivity." }
      end

      def perform_http_request(request_class, path, body)
        uri = URI("#{API_BASE_URL}#{path}")
        request = request_class.new(uri)
        request["Authorization"] = "Bearer #{@secret_key}"
        request["Content-Type"] = "application/json"
        request.body = body.to_json if body

        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
          http.request(request)
        end
      end

      def parse_response_body(response)
        parsed = JSON.parse(response.body)
        parsed["_http_status"] = response.code.to_i if parsed.is_a?(Hash)
        parsed
      end

      def inline_retry_delay(attempt)
        delay = INLINE_RETRY_BASE_SECONDS * (2**(attempt - 1))
        [ delay, INLINE_RETRY_MAX_SECONDS ].min
      end
    end
  end
end
