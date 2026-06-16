# frozen_string_literal: true

class AddUniqueSettlementPerTip < ActiveRecord::Migration[8.0]
  def up
    dedupe_tip_settlements!

    add_index :paystack_settlements,
              %i[tribe_id tip_id],
              unique: true,
              where: "tip_id IS NOT NULL",
              name: "index_paystack_settlements_on_tribe_id_and_tip_id_unique"
  end

  def down
    remove_index :paystack_settlements,
                 name: "index_paystack_settlements_on_tribe_id_and_tip_id_unique"
  end

  private

  def dedupe_tip_settlements!
    say_with_time "Deduplicating tip-linked settlements" do
      duplicates = PaystackSettlement.where.not(tip_id: nil)
        .select(:tribe_id, :tip_id)
        .group(:tribe_id, :tip_id)
        .having("COUNT(*) > 1")

      duplicates.each do |row|
        settlements = PaystackSettlement.where(tribe_id: row.tribe_id, tip_id: row.tip_id)
          .order(Arel.sql("COALESCE(settled_at, created_at) DESC"))

        keeper = settlements.find { |s| Tribetip::Paystack::SettlementRecord.authoritative_transfer_code?(s.paystack_transfer_code) } ||
                 settlements.first
        settlements.where.not(id: keeper.id).delete_all
      end
    end
  end
end
