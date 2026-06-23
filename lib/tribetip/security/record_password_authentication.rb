# frozen_string_literal: true

module Tribetip
  module Security
    class RecordPasswordAuthentication
      def self.call(tribe, at: Time.current)
        return unless tribe

        tribe.update!(last_password_authenticated_at: at)
      end
    end
  end
end
