# frozen_string_literal: true

require Rails.root.join("lib/tribetip/platform")

Rails.application.config.x.platform = {
  app_url: Tribetip::Platform.app_url,
  api_url: Tribetip::Platform.api_url
}

Rails.application.config.action_mailer.default_url_options =
  Tribetip::Platform.mailer_url_options
