# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Referrals::AttachOnSignup do
  it "creates a referral when the code matches an eligible referrer" do
    referrer = create_creator(username: "eligible_referrer")
    referred = create_tribe(username: "new_referred")

    expect {
      described_class.call(referred: referred, referral_code: referrer.username)
    }.to change(Referral, :count).by(1)

    referred.reload
    referral = Referral.find_by!(referred: referred)

    expect(referred.referred_by_id).to eq(referrer.id)
    expect(referral.referrer).to eq(referrer)
    expect(referral.status).to eq("pending")
    expect(referral.referral_code_used).to eq("eligible_referrer")
  end

  it "ignores invalid referral codes" do
    referred = create_tribe(username: "no_ref_creator")

    expect {
      described_class.call(referred: referred, referral_code: "unknown_creator")
    }.not_to change(Referral, :count)

    expect(referred.reload.referred_by_id).to be_nil
  end

  it "ignores referral codes from creators who are not eligible yet" do
    referrer = create_tribe(username: "pending_only", account_status: "pending")
    clear_paystack_onboarding!(referrer.reload)
    expect(Tribetip::Referrals::ResolveCode.call(referrer.username)).to be_nil

    referred = create_tribe(username: "ignored_ref")

    described_class.call(referred: referred, referral_code: referrer.username)

    expect(Referral.where(referred: referred).count).to eq(0)
    expect(referred.reload.referred_by_id).to be_nil
  end

  it "does not attach when the referred creator is the referrer" do
    referrer = create_creator(username: "same_person")

    expect {
      described_class.call(referred: referrer, referral_code: referrer.username)
    }.not_to change(Referral, :count)
  end

  it "does not overwrite an existing referral" do
    referrer = create_creator(username: "first_referrer")
    other_referrer = create_creator(username: "second_referrer")
    referred = create_tribe(username: "already_referred")
    described_class.call(referred: referred, referral_code: referrer.username)

    expect {
      described_class.call(referred: referred.reload, referral_code: other_referrer.username)
    }.not_to change(Referral, :count)

    expect(referred.reload.referred_by_id).to eq(referrer.id)
  end

  it "does not attach when signup IP matches the referrer IP" do
    referrer = create_creator(username: "same_ip_referrer")
    referrer.update!(current_sign_in_ip: "198.51.100.20")
    referred = create_tribe(username: "same_ip_referred")

    described_class.call(
      referred: referred,
      referral_code: referrer.username,
      signup_ip: "198.51.100.20"
    )

    expect(Referral.where(referred: referred)).to be_empty
    expect(referred.reload.referred_by_id).to be_nil
  end

  it "does not attach when the referrer has referrals turned off" do
    referrer = create_creator(username: "disabled_referrer", referrals_enabled: false)
    referred = create_tribe(username: "disabled_ref_friend")

    described_class.call(referred: referred, referral_code: referrer.username)

    expect(Referral.where(referred: referred)).to be_empty
    expect(referred.reload.referred_by_id).to be_nil
  end
end
