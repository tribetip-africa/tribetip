# Be sure to restart your server when you modify this file.

require Rails.root.join("lib/tribetip/platform")

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

allowed_origins = Tribetip::Platform.cors_origins

if allowed_origins.empty? && !Rails.env.development?
  # Deny cross-origin browser calls outside development unless explicitly configured.
  allowed_origins = []
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"

    resource "/widget/config",
      headers: :any,
      methods: %i[get options],
      max_age: 600
  end

  allow do
    origins(*allowed_origins)

    resource "*",
      headers: :any,
      expose: [ "Authorization" ],
      methods: %i[get post put patch delete options head],
      max_age: 600
  end
end
