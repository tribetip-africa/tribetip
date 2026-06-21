require 'rails_helper'

RSpec.describe Tribe, type: :model do
  describe "devise configuration" do
    subject(:devise_modules) { described_class.devise_modules }

    it { expect(devise_modules).to include(:database_authenticatable) }
    it { expect(devise_modules).to include(:registerable) }
    it { expect(devise_modules).to include(:recoverable) }
    it { expect(devise_modules).to include(:validatable) }
    it { expect(devise_modules).to include(:confirmable) }
    it { expect(devise_modules).to include(:lockable) }
    it { expect(devise_modules).to include(:trackable) }
    it { expect(devise_modules).to include(:jwt_authenticatable) }
  end

  describe "validations" do
    subject(:tribe) do
      described_class.new(
        email: "owner@tribetip.africa",
        password: "securepass123",
        username: "tribe_owner"
      )
    end

    it "is valid with email and password" do
      expect(tribe).to be_valid
    end

    it "is invalid without email" do
      tribe.email = nil

      expect(tribe).not_to be_valid
    end

    it "is invalid with an improperly formatted email" do
      tribe.email = "bad_email"

      expect(tribe).not_to be_valid
    end

    it "is invalid with a short password" do
      tribe.password = "12345"

      expect(tribe).not_to be_valid
    end

    it "normalizes username before validation" do
      tribe.username = " Tribe_Owner "
      tribe.validate

      expect(tribe.username).to eq("tribe_owner")
    end

    it "is invalid without a username" do
      tribe.username = nil

      expect(tribe).not_to be_valid
    end

    it "is invalid with an unsupported country code" do
      tribe.country_code = "TZ"

      expect(tribe).not_to be_valid
    end

    it "is invalid with an unsupported currency" do
      tribe.currency = "EUR"

      expect(tribe).not_to be_valid
    end

    it "requires positive default tip amount" do
      tribe.default_tip_amount_cents = 0

      expect(tribe).not_to be_valid
    end

    it "requires display_name when profile is public" do
      tribe.is_profile_public = true

      expect(tribe).not_to be_valid
    end
  end

  describe "Paystack onboarding" do
    subject(:tribe) do
      described_class.new(
        email: "paystack@tribetip.africa",
        password: "securepass123",
        username: "paystack_user"
      )
    end

    it "is incomplete without Paystack codes" do
      expect(tribe.paystack_onboarding_complete?).to be(false)
    end

    it "is complete when customer, subaccount, and timestamp are present" do
      tribe.paystack_customer_code = "cus_test"
      tribe.paystack_subaccount_code = "acct_test"
      tribe.onboarding_completed_at = Time.current

      expect(tribe.paystack_onboarding_complete?).to be(true)
    end

    it "marks onboarding complete when both Paystack codes exist" do
      tribe.save!
      tribe.paystack_customer_code = "cus_test"
      tribe.paystack_subaccount_code = "acct_test"

      tribe.mark_paystack_onboarding_complete!

      expect(tribe.reload.onboarding_completed_at).to be_present
    end

    it "activates pending accounts when Paystack onboarding completes" do
      tribe.save!
      tribe.paystack_customer_code = "cus_test"
      tribe.paystack_subaccount_code = "acct_test"

      tribe.mark_paystack_onboarding_complete!

      expect(tribe.reload.account_status).to eq("active")
    end
  end

  describe "cache invalidation" do
    include_context "with memory cache"

    it "purges the public profile cache after update" do
      tribe = create_public_tribe(username: "cache_purge", display_name: "Creator")
      cache_key = Tribetip::SecureCache.public_profile_key(tribe.username)

      Tribetip::SecureCache.fetch(cache_key, scope: :public) { { display_name: "Creator" } }
      tribe.update!(display_name: "Updated")

      expect(Tribetip::SecureCache.read(cache_key, scope: :public)).to be_nil
    end

    it "purges payout status cache when onboarding state changes" do
      tribe = create_tribe(username: "payout_cache_purge")
      complete_stub_paystack_onboarding!(tribe)
      cache_key = Tribetip::Paystack::FetchPayoutStatus.cache_key_for(tribe.reload)

      Tribetip::SecureCache.fetch(cache_key, scope: :public) { { subaccount_verified: true } }
      tribe.update!(account_status: "suspended")

      expect(Tribetip::SecureCache.read(cache_key, scope: :public)).to be_nil
    end
  end
end
