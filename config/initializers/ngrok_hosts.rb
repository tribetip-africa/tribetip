# frozen_string_literal: true

# Allow Paystack webhooks through ngrok tunnels during local Docker development.
# Enable with TRIBETIP_ALLOW_NGROK_HOSTS=true (set in docker-compose.yml).
if ActiveModel::Type::Boolean.new.cast(ENV["TRIBETIP_ALLOW_NGROK_HOSTS"])
  Rails.application.config.hosts << /[a-z0-9-]+\.ngrok-free\.app/
  Rails.application.config.hosts << /[a-z0-9-]+\.ngrok\.io/
  Rails.application.config.hosts << /[a-z0-9-]+\.ngrok\.app/
end
