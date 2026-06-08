# frozen_string_literal: true

module Tribetip
  module Metrics
    class TribeTipStats
      def self.for_tribes(tribes)
        new(tribes).call
      end

      def initialize(tribes)
        @tribes = Array(tribes)
      end

      def call
        return {} if @tribes.empty?

        rows = Tip.where(tribe_id: @tribes.map(&:id))
                  .group(:tribe_id, :status)
                  .pluck(
                    :tribe_id,
                    :status,
                    Arel.sql("COUNT(*)"),
                    Arel.sql("COALESCE(SUM(amount_cents), 0)")
                  )

        stats = Hash.new do |hash, tribe_id|
          hash[tribe_id] = {
            paid_tips_count: 0,
            pending_tips_count: 0,
            failed_tips_count: 0,
            total_earned_cents: 0,
            pending_tips_cents: 0
          }
        end

        rows.each do |tribe_id, status, count, cents|
          entry = stats[tribe_id]
          case status
          when "paid"
            entry[:paid_tips_count] = count
            entry[:total_earned_cents] = cents
          when "pending"
            entry[:pending_tips_count] = count
            entry[:pending_tips_cents] = cents
          when "failed"
            entry[:failed_tips_count] = count
          end
        end

        stats
      end
    end
  end
end
