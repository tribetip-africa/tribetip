# frozen_string_literal: true

# Docker local dev runs RAILS_ENV=production without SMTP. Default to :test delivery
# unless SMTP or an explicit delivery method is configured.
return if Rails.env.test?

smtp_address = ENV["SMTP_ADDRESS"].presence || ENV["ACTION_MAILER_SMTP_ADDRESS"].presence
explicit_method = ENV["ACTION_MAILER_DELIVERY_METHOD"].presence

if smtp_address.present?
  Rails.application.config.action_mailer.delivery_method = :smtp
  Rails.application.config.action_mailer.smtp_settings = {
    address: smtp_address,
    port: ENV.fetch("SMTP_PORT", "587").to_i,
    user_name: ENV["SMTP_USERNAME"].presence,
    password: ENV["SMTP_PASSWORD"].presence,
    authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
    enable_starttls_auto: ActiveModel::Type::Boolean.new.cast(
      ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", "true")
    )
  }.compact
elsif explicit_method.present?
  Rails.application.config.action_mailer.delivery_method = explicit_method.to_sym
else
  Rails.application.config.action_mailer.delivery_method = :test
end

Rails.application.config.action_mailer.raise_delivery_errors = false
