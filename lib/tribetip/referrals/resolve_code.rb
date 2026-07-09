# frozen_string_literal: true

module Tribetip
  module Referrals
    class ResolveCode
      def self.call(code)
        ResolveReferral.call(code)&.referrer
      end
    end
  end
end
