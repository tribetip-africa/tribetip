class Tribe < ApplicationRecord
  VALID_COUNTRY_CODES = %w[NG GH KE ZA CI].freeze
  VALID_CURRENCIES = %w[NGN GHS KES ZAR XOF USD].freeze
  VALID_ACCOUNT_STATUSES = %w[pending active suspended].freeze
  VALID_ROLES = %w[creator admin].freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :validatable,
         :confirmable, :lockable, :trackable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  has_paper_trail skip: %i[
    encrypted_password
    reset_password_token
    remember_created_at
    confirmation_token
    unconfirmed_email
    unlock_token
    failed_attempts
    current_sign_in_ip
    last_sign_in_ip
  ],
  meta: {
    request_id: :request_id,
    ip: :ip,
    user_agent: :user_agent
  }

  before_validation :normalize_username
  before_validation :enforce_creator_only_public_profile
  after_initialize :set_default_role, if: :new_record?
  after_commit :purge_public_profile_cache, on: %i[update destroy]
  after_commit :purge_payout_status_cache, on: :update
  after_create :enqueue_paystack_customer_provision

  has_many :tips, dependent: :destroy
  has_many :paystack_settlements, dependent: :destroy
  has_many :creator_notifications, dependent: :destroy

  validates :username, presence: true,
                       format: { with: /\A[a-z0-9_]+\z/ },
                       length: { minimum: 3, maximum: 30 },
                       uniqueness: { case_sensitive: false }
  validates :display_name, presence: true, if: :is_profile_public?
  validates :bio, length: { maximum: 500 }, allow_blank: true
  validates :country_code, inclusion: { in: VALID_COUNTRY_CODES }
  validate :country_code_must_be_enabled, if: :country_code_changed?
  validates :currency, inclusion: { in: VALID_CURRENCIES }
  validates :default_tip_amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :account_status, inclusion: { in: VALID_ACCOUNT_STATUSES }
  validates :role, inclusion: { in: VALID_ROLES }
  validate :email_acceptable_for_paystack, on: :create
  validate :admin_cannot_have_public_profile

  PAYSTACK_REJECTED_EMAIL_SUFFIXES = %w[.local .localhost .invalid .test .example].freeze

  def admin?
    role == "admin"
  end

  def creator?
    role == "creator"
  end

  def paystack_sync_required?
    creator?
  end

  def suspended?
    account_status == "suspended"
  end

  def paystack_customer_ready?
    paystack_customer_code.present?
  end

  def paystack_subaccount_ready?
    paystack_subaccount_code.present?
  end

  def paystack_onboarding_complete?
    onboarding_completed_at.present? &&
      paystack_customer_ready? &&
      paystack_subaccount_ready?
  end

  def mark_paystack_onboarding_complete!
    return unless paystack_customer_ready? && paystack_subaccount_ready?

    attrs = {}
    attrs[:onboarding_completed_at] = Time.current if onboarding_completed_at.blank?
    attrs[:account_status] = "active" if account_status == "pending"
    update!(attrs) if attrs.present?
  end

  def paystack_market
    Tribetip::Paystack::Market.for_tribe(self)
  end

  def self.find_for_database_authentication(warden_conditions)
    login = warden_conditions[:login].to_s.strip.downcase
    return nil if login.blank?

    if login.include?("@")
      find_by(email: login)
    else
      find_by(username: login)
    end
  end

  private

  def normalize_username
    self.username = username.to_s.strip.downcase.presence
  end

  def set_default_role
    self.role = "creator" if role.blank?
  end

  def enforce_creator_only_public_profile
    self.is_profile_public = false unless creator?
  end

  def admin_cannot_have_public_profile
    return unless admin? && is_profile_public?

    errors.add(:is_profile_public, "cannot be enabled for admin accounts")
  end

  def enqueue_paystack_customer_provision
    return unless paystack_sync_required?

    ::Paystack::ProvisionCustomerJob.perform_later(id)
  end

  def country_code_must_be_enabled
    return if country_code.blank?
    return if Tribetip::Regions.enabled?(country_code)

    errors.add(:country_code, "is not available yet")
  end

  def email_acceptable_for_paystack
    return if Tribetip::Paystack::Client.new.stub_mode?
    return if email.blank?

    domain = email.to_s.split("@", 2).last.to_s.downcase
    return if domain.blank?

    if PAYSTACK_REJECTED_EMAIL_SUFFIXES.any? { |suffix| domain.end_with?(suffix) } || domain == "localhost"
      errors.add(:email, "must be a real address Paystack accepts (for example you@gmail.com)")
    end
  end

  def purge_public_profile_cache
    return if username.blank?

    Tribetip::SecureCache.delete(Tribetip::SecureCache.public_profile_key(username))
    Tribetip::SecureCache.bump_version!(:public) if saved_change_to_username?
  end

  def purge_payout_status_cache
    return unless payout_cache_relevant_change?

    Tribetip::Paystack::FetchPayoutStatus.invalidate_cache(self)
  end

  def payout_cache_relevant_change?
    saved_change_to_paystack_subaccount_code? ||
      saved_change_to_onboarding_completed_at? ||
      saved_change_to_account_status? ||
      saved_change_to_is_profile_public?
  end
end
