# frozen_string_literal: true

module TribeFactoryHelpers
  def create_tribe(username:, account_status: "pending", display_name: nil, email: nil, country_code: nil, **attrs)
    attributes = {
      email: email || "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      account_status: account_status,
      display_name: display_name
    }.merge(attrs)

    if country_code && !attributes.key?(:currency)
      market = Tribetip::Paystack::Market.find(country_code)
      attributes[:country_code] = country_code
      attributes[:currency] = market.currency
    end

    tribe = Tribe.new(attributes)
    tribe.skip_confirmation!
    tribe.save!
    tribe
  end

  def create_onboarded_tribe(username:, account_status: "active", **attrs)
    tribe = create_tribe(username: username, account_status: account_status, **attrs)
    complete_stub_paystack_onboarding!(tribe)
    tribe.reload
  end

  def create_public_tribe(username: "public_creator", display_name: "Public Creator", **attrs)
    create_tribe(
      username: username,
      display_name: display_name,
      is_profile_public: true,
      account_status: "active",
      **attrs
    )
  end

  def create_creator(username: "widget_creator", display_name: nil, **attrs)
    tribe = create_public_tribe(
      username: username,
      display_name: display_name || username.tr("_", " ").split.map(&:capitalize).join(" "),
      **attrs
    )
    complete_stub_paystack_onboarding!(tribe)
    tribe.reload
  end
end

RSpec.configure do |config|
  config.include TribeFactoryHelpers
end
