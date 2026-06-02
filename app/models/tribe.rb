class Tribe < ApplicationRecord
  VALID_COUNTRY_CODES = %w[NG GH KE ZA CI].freeze
  VALID_CURRENCIES = %w[NGN GHS KES ZAR XOF USD].freeze
  VALID_ACCOUNT_STATUSES = %w[pending active suspended].freeze

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
  ]

  before_validation :normalize_username

  validates :username, presence: true,
                       format: { with: /\A[a-z0-9_]+\z/ },
                       length: { minimum: 3, maximum: 30 },
                       uniqueness: { case_sensitive: false }
  validates :display_name, presence: true, if: :is_profile_public?
  validates :bio, length: { maximum: 500 }, allow_blank: true
  validates :country_code, inclusion: { in: VALID_COUNTRY_CODES }
  validates :currency, inclusion: { in: VALID_CURRENCIES }
  validates :default_tip_amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :account_status, inclusion: { in: VALID_ACCOUNT_STATUSES }

  private

  def normalize_username
    self.username = username.to_s.strip.downcase.presence
  end
end
