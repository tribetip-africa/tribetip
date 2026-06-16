# frozen_string_literal: true

module Tribetip
  module Paystack
    class ListSettlements
      DEFAULT_LIMIT = 20

      Result = Struct.new(:settlements, :source, :refreshed_at, :synced_at, keyword_init: true)

      def self.call(tribe, refresh: false, limit: DEFAULT_LIMIT)
        new(tribe, limit: limit).call(refresh: refresh)
      end

      def self.cache_key_for(tribe)
        "paystack_settlements/#{tribe.id}/#{tribe.paystack_subaccount_code}"
      end

      def self.invalidate_cache(tribe)
        Tribetip::SecureCache.delete(cache_key_for(tribe))
      end

      def initialize(tribe, limit: DEFAULT_LIMIT)
        @tribe = tribe
        @limit = limit
        @client = Client.new
        @market = Market.for_tribe(tribe)
      end

      def call(refresh: false)
        synced_at = nil
        if refresh || @tribe.paystack_settlements.none?
          synced_at = sync_from_remote!
        end

        settlements = load_from_database
        Result.new(
          settlements: settlements,
          source: "database",
          refreshed_at: Time.current,
          synced_at: synced_at
        )
      end

      private

      def load_from_database
        @tribe.paystack_settlements.recent_first.limit(@limit).map(&:to_settlement_record)
      end

      def sync_from_remote!
        return Time.current unless @tribe.paystack_subaccount_ready?

        remote_rows = fetch_remote_settlements
        remote_rows.each do |record|
          RecordSettlement.call(tribe: @tribe, record: record)
        end

        self.class.invalidate_cache(@tribe)
        Time.current
      end

      def fetch_remote_settlements
        if @client.stub_mode?
          return stub_settlements
        end

        response = @client.list_transfers(per_page: 50)
        return stub_settlements unless response.success?

        Array(response.data).filter_map do |row|
          next unless transfer_belongs_to_tribe?(row)

          SettlementRecord.from_transfer(row, tribe: @tribe)
        end
      end

      def transfer_belongs_to_tribe?(row)
        data = row.is_a?(Hash) ? row.with_indifferent_access : {}
        metadata = data[:metadata].is_a?(Hash) ? data[:metadata].with_indifferent_access : {}
        reason = data[:reason].to_s

        metadata[:tribe_id].to_s == @tribe.id.to_s ||
          metadata[:subaccount_code].to_s == @tribe.paystack_subaccount_code.to_s ||
          reason.include?(@tribe.paystack_subaccount_code.to_s)
      end

      def stub_settlements
        destination = stub_destination_label
        tips_needing_stub_settlement(destination)
      end

      def tips_needing_stub_settlement(destination)
        settled_tip_ids = @tribe.paystack_settlements.where.not(tip_id: nil).pluck(:tip_id)
        settled_references = @tribe.paystack_settlements.pluck(:reference).compact

        @tribe.tips.paid
          .where.not(id: settled_tip_ids)
          .where.not(paystack_reference: settled_references)
          .order(paid_at: :desc)
          .limit(@limit)
          .filter_map do |tip|
            stub_code = SettlementRecord.transfer_code_for_tip(tip)
            next if PaystackSettlement.exists?(paystack_transfer_code: stub_code)

            SettlementRecord.from_stub_tip(tip, tribe: @tribe, destination: destination)
          end
      end

      def stub_destination_label
        payout = FetchPayoutStatus.call(@tribe)
        bank = payout.settlement_bank.presence || @market.stub_settlement_bank
        account = payout.account_number.presence || SettlementRecord.mask_account_number(@market.stub_account_number)
        [ bank, account ].compact.join(" · ")
      end
    end
  end
end
