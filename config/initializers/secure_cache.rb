# frozen_string_literal: true

require Rails.root.join("lib/tribetip/secure_cache")

Rails.application.config.x.secure_cache = {
  enabled: !Rails.env.test?,
  scopes: Tribetip::SecureCache::SCOPES.keys
}
