# frozen_string_literal: true

module Tribetip
  module Security
    class RevokeBearerToken
      def self.call(token)
        new(token).call
      end

      def initialize(token)
        @token = token
      end

      def call
        return if @token.blank?

        payload = Warden::JWTAuth::TokenDecoder.new.call(@token)
        JwtDenylist.create!(
          jti: payload["jti"],
          exp: Time.zone.at(payload["exp"])
        )
      rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError, ActiveRecord::RecordNotUnique
        nil
      end
    end
  end
end
