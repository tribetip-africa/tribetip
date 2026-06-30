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

    it "rejects passwords shorter than the 8-character minimum" do
      tribe.password = "1234567"
      tribe.password_confirmation = "1234567"

      expect(tribe).not_to be_valid
      expect(tribe.errors[:password]).to be_present
    end

    it "accepts passwords at the 8-character minimum" do
      tribe.password = "12345678"
      tribe.password_confirmation = "12345678"

      expect(tribe).to be_valid
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

    it "is invalid when the username is reserved" do
      tribe.username = "dashboard"

      expect(tribe).not_to be_valid
      expect(tribe.errors[:username]).to include("is reserved and cannot be used")
    end

    it "rejects reserved usernames that collide with frontend routes" do
      %w[faq terms privacy api admin support].each do |reserved|
        tribe.username = reserved

        expect(tribe).not_to be_valid, "expected '#{reserved}' to be rejected"
      end
    end

    it "rejects reserved usernames regardless of casing/whitespace" do
      tribe.username = "  ADMIN "
      tribe.validate

      expect(tribe.username).to eq("admin")
      expect(tribe.errors[:username]).to include("is reserved and cannot be used")
    end

    it "allows usernames that merely contain a reserved word" do
      tribe.username = "admin123"

      expect(tribe).to be_valid
    end

    it "does not re-validate the reserved list on saves that leave the username unchanged" do
      tribe.save!
      tribe.update_column(:username, "admin") # bypass validation to simulate a legacy record

      expect(tribe.update(display_name: "Legacy Creator")).to be(true)
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

  describe "widget embed validations" do
    subject(:tribe) do
      described_class.new(
        email: "widget@tribetip.africa",
        password: "securepass123",
        username: "widget_owner"
      )
    end

    it "accepts an https destination URL" do
      tribe.widget_destination_url = "https://example.com/tip"

      expect(tribe).to be_valid
    end

    it "rejects a javascript: destination URL" do
      tribe.widget_destination_url = "javascript:alert(1)"

      expect(tribe).not_to be_valid
      expect(tribe.errors[:widget_destination_url]).to be_present
    end

    it "rejects a data: destination URL" do
      tribe.widget_destination_url = "data:text/html,<script>alert(1)</script>"

      expect(tribe).not_to be_valid
      expect(tribe.errors[:widget_destination_url]).to be_present
    end

    it "accepts an https icon URL" do
      tribe.widget_icon_url = "https://cdn.example.com/avatar.png"

      expect(tribe).to be_valid
    end

    it "rejects a javascript: icon URL" do
      tribe.widget_icon_url = "javascript:alert(document.cookie)"

      expect(tribe).not_to be_valid
      expect(tribe.errors[:widget_icon_url]).to be_present
    end

    it "rejects a data: icon URL" do
      tribe.widget_icon_url = "data:image/svg+xml,<svg onload=alert(1)>"

      expect(tribe).not_to be_valid
      expect(tribe.errors[:widget_icon_url]).to be_present
    end

    it "allows a blank icon URL" do
      tribe.widget_icon_url = nil

      expect(tribe).to be_valid
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
