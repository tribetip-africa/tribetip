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

      def initialize(secret_key: ENV["PAYSTACK_SECRET_KEY"])
        @secret_key = secret_key.to_s
      end

      def stub_mode?
        @secret_key.blank?
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

      def create_subaccount(business_name:, settlement_bank:, account_number:, percentage_charge:, primary_contact_email:, currency:, metadata: {})
        return stub_resource("acct") if stub_mode?

        response = post("/subaccount", {
          business_name: business_name,
          settlement_bank: settlement_bank,
          account_number: account_number,
          percentage_charge: percentage_charge,
          primary_contact_email: primary_contact_email,
          currency: currency,
          metadata: metadata
        })

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
            "settlement_schedule" => "AUTO",
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
        if paystack_bank_country == "kenya"
          banks << {
            "name" => "M-PESA",
            "code" => "MPESA",
            "country" => paystack_bank_country,
            "currency" => "KES",
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
        uri = URI("#{API_BASE_URL}#{path}")
        request = request_class.new(uri)
        request["Authorization"] = "Bearer #{@secret_key}"
        request["Content-Type"] = "application/json"
        request.body = body.to_json if body

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
          http.request(request)
        end

        JSON.parse(response.body)
      rescue JSON::ParserError
        { "status" => false, "message" => "Invalid Paystack response" }
      end
    end
  end
end
