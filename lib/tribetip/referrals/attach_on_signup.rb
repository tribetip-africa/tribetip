# frozen_string_literal: true

module Tribetip
  module Referrals
    # @deprecated Prefer {Attach}. Kept as a thin alias for older call sites/specs.
    class AttachOnSignup
      def self.call(referred:, referral_code:, signup_ip: nil)
        Attach.call(referred: referred, referral_code: referral_code, attach_ip: signup_ip)
      end
    end
  end
end
