# frozen_string_literal: true

module Tribetip
  module Referrals
    class UpdateSettings
      def self.call(tribe:, referrals_enabled:)
        new(tribe: tribe, referrals_enabled: referrals_enabled).call
      end

      def initialize(tribe:, referrals_enabled:)
        @tribe = tribe
        @referrals_enabled = cast_enabled_flag!(referrals_enabled)
      end

      def call
        ActiveRecord::Base.transaction do
          @tribe.update!(referrals_enabled: @referrals_enabled)

          if @referrals_enabled
            Invites.ensure_active!(@tribe) if Config.enabled? && Referrals.eligible_referrer?(@tribe)
          else
            Invites.revoke_all!(@tribe)
          end
        end

        { success: true, referrals: BuildSummary.call(@tribe.reload) }
      rescue ActiveRecord::RecordInvalid
        failure
      end

      private

      def cast_enabled_flag!(value)
        unless [ true, false ].include?(value) || value.is_a?(String) || value.is_a?(Numeric)
          raise ArgumentError, "referrals_enabled must be true or false"
        end

        cast = ActiveModel::Type::Boolean.new.cast(value)
        raise ArgumentError, "referrals_enabled must be true or false" if cast.nil?

        cast
      end

      def failure
        {
          success: false,
          errors: @tribe.errors.full_messages
        }
      end
    end
  end
end
