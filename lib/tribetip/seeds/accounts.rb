# frozen_string_literal: true

module Tribetip
  module Seeds
    class Accounts
      DEV_PASSWORD = "TribetipDev1!"

      ADMIN_ACCOUNTS = [
        {
          key: :superadmin,
          username: "superadmin",
          email: "superadmin@tribetip.africa",
          display_name: "TribeTip Super Admin",
          role: "admin"
        },
        {
          key: :admin,
          username: "platform_admin",
          email: "admin@tribetip.africa",
          display_name: "TribeTip Platform Admin",
          role: "admin"
        }
      ].freeze

      CREATOR_ACCOUNTS = [
        {
          key: :demo_creator,
          username: "demo_creator",
          email: "demo@tribetip.africa",
          display_name: "Demo Creator",
          bio: "Sample Kenyan creator page for local development and demos.",
          published: true,
          onboarded: true,
          sample_tips: true
        },
        {
          key: :kenya_creator,
          username: "kenya_creator",
          email: "kenya@tribetip.africa",
          display_name: "Kenya Creator",
          bio: "Onboarded creator who has not published yet — useful for testing publish gating.",
          published: false,
          onboarded: true,
          sample_tips: false
        },
        {
          key: :new_creator,
          username: "new_creator",
          email: "new@tribetip.africa",
          display_name: "New Creator",
          bio: nil,
          published: false,
          onboarded: false,
          sample_tips: false
        }
      ].freeze

      SAMPLE_TIPS = [
        {
          reference: "seed_tip_paid_1",
          amount_cents: 500_00,
          status: "paid",
          supporter_name: "Alex",
          supporter_email: "alex@example.com",
          message: "Love the content!"
        },
        {
          reference: "seed_tip_paid_2",
          amount_cents: 1_000_00,
          status: "paid",
          supporter_name: "Sam",
          supporter_email: "sam@example.com",
          message: "Keep going!"
        },
        {
          reference: "seed_tip_pending_1",
          amount_cents: 250_00,
          status: "pending",
          supporter_name: "Jordan",
          supporter_email: "jordan@example.com",
          message: nil
        }
      ].freeze

      Result = Struct.new(:key, :email, :created, :updated, :skipped, keyword_init: true)

      class << self
        def call(**options)
          new(**options).tap(&:call)
        end

        def allowed?
          return true if Rails.env.development? || Rails.env.test?

          ActiveModel::Type::Boolean.new.cast(ENV["TRIBETIP_SEED_ENABLED"])
        end
      end

      def initialize(reset_password: false, include_creators: true)
        @reset_password = reset_password
        @include_creators = include_creators
        @results = []
      end

      def call
        raise "Refusing to seed accounts in #{Rails.env} (set TRIBETIP_SEED_ENABLED=true)" unless self.class.allowed?

        password = seed_password

        ADMIN_ACCOUNTS.each { |attrs| seed_admin!(attrs, password) }
        CREATOR_ACCOUNTS.each { |attrs| seed_creator!(attrs, password) } if @include_creators
        self
      end

      def summary
        @results
      end

      private

      def seed_password
        if ENV["TRIBETIP_SEED_PASSWORD"].present?
          return ENV["TRIBETIP_SEED_PASSWORD"]
        end

        if Rails.env.production?
          raise "TRIBETIP_SEED_PASSWORD is required when seeding production"
        end

        DEV_PASSWORD
      end

      def seed_admin!(attrs, password)
        tribe = find_or_build(attrs[:email], attrs[:username])
        created = tribe.new_record?

        assign_base_attributes(
          tribe,
          attrs,
          password: password,
          country_code: default_country_code,
          currency: default_currency
        )
        tribe.role = attrs[:role]
        tribe.account_status = "active"
        tribe.is_profile_public = false
        tribe.paystack_customer_code = nil
        tribe.paystack_subaccount_code = nil
        tribe.onboarding_completed_at = nil
        tribe.paystack_provisioning_error = nil
        tribe.terms_accepted_at ||= Time.current

        save_account!(tribe, created:, label: attrs[:key])
      end

      def seed_creator!(attrs, password)
        tribe = find_or_build(attrs[:email], attrs[:username])
        created = tribe.new_record?

        assign_base_attributes(
          tribe,
          attrs,
          password: password,
          country_code: default_country_code,
          currency: default_currency
        )
        tribe.role = "creator"
        tribe.display_name = attrs[:display_name]
        tribe.bio = attrs[:bio] if attrs[:bio].present?
        tribe.terms_accepted_at ||= Time.current

        if attrs[:onboarded]
          apply_onboarded_state!(tribe)
        else
          clear_onboarded_state!(tribe)
        end

        tribe.is_profile_public = attrs[:published] && tribe.paystack_onboarding_complete?
        tribe.account_status = tribe.paystack_onboarding_complete? ? "active" : "pending"

        save_account!(tribe, created:, label: attrs[:key])
        seed_sample_tips!(tribe) if attrs[:sample_tips]
      end

      def find_or_build(email, username)
        Tribe.find_by(email: email) || Tribe.find_by(username: username) || Tribe.new(email: email, username: username)
      end

      def assign_base_attributes(tribe, attrs, password:, country_code:, currency:)
        tribe.email = attrs[:email]
        tribe.username = attrs[:username]
        tribe.display_name = attrs[:display_name] if attrs[:display_name].present?
        tribe.country_code = country_code
        tribe.currency = currency
        tribe.password = password
        tribe.password_confirmation = password
        tribe.skip_confirmation!
      end

      def apply_onboarded_state!(tribe)
        suffix = tribe.username.presence || SecureRandom.hex(4)
        tribe.paystack_customer_code ||= "cus_seed_#{suffix}"
        tribe.paystack_subaccount_code ||= "acct_seed_#{suffix}"
        tribe.onboarding_completed_at ||= Time.current
        tribe.paystack_provisioning_error = nil
      end

      def clear_onboarded_state!(tribe)
        tribe.paystack_customer_code = nil
        tribe.paystack_subaccount_code = nil
        tribe.onboarding_completed_at = nil
        tribe.paystack_provisioning_error = nil
        tribe.is_profile_public = false
      end

      def save_account!(tribe, created:, label:)
        changed = created || tribe.changed? || @reset_password
        if changed
          tribe.save!
          @results << Result.new(created: created, updated: !created, skipped: false, key: label, email: tribe.email)
        else
          @results << Result.new(created: false, updated: false, skipped: true, key: label, email: tribe.email)
        end
      end

      def seed_sample_tips!(tribe)
        SAMPLE_TIPS.each do |attrs|
          tip = tribe.tips.find_or_initialize_by(paystack_reference: attrs[:reference])
          tip.assign_attributes(
            amount_cents: attrs[:amount_cents],
            currency: tribe.currency,
            status: attrs[:status],
            supporter_name: attrs[:supporter_name],
            supporter_email: attrs[:supporter_email],
            message: attrs[:message],
            paid_at: attrs[:status] == "paid" ? Time.current : nil,
            paid_via: attrs[:status] == "paid" ? "webhook" : nil
          )
          tip.save!
        end
      end

      def default_country_code
        code = Tribetip::Regions.default_country_code
        return code if Tribetip::Regions.enabled?(code)

        "KE"
      end

      def default_currency
        Tribetip::Paystack::Market.find(default_country_code).currency
      end
    end
  end
end
