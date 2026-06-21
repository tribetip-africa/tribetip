# frozen_string_literal: true

# Defense-in-depth headers for the JSON API. Browsers rarely render API responses,
# but these protect any HTML error payloads and align with security scanner expectations.
Rails.application.config.action_dispatch.default_headers.merge!(
  "Content-Security-Policy" => "default-src 'none'; frame-ancestors 'none'",
  "Permissions-Policy" => "accelerometer=(), camera=(), geolocation=(), gyroscope=(), " \
                          "magnetometer=(), microphone=(), payment=(), usb=()"
)
