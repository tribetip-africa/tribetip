# frozen_string_literal: true

# Route reads to primary_replica and writes to primary in development and production.
# Test keeps a single database (see config/database.yml).
if Rails.env.development? || Rails.env.production?
  Rails.application.config.active_record.database_selector = { delay: 2.seconds }
  Rails.application.config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
  Rails.application.config.active_record.database_resolver_context =
    ActiveRecord::Middleware::DatabaseSelector::Resolver::Session

  # DatabaseSelector stores last-write timestamps in the session; enable cookies before it.
  Rails.application.config.session_store :cookie_store, key: "_tribetip_session"
  Rails.application.config.middleware.insert_before ActiveRecord::Middleware::DatabaseSelector,
    ActionDispatch::Cookies
  Rails.application.config.middleware.insert_before ActiveRecord::Middleware::DatabaseSelector,
    ActionDispatch::Session::CookieStore, Rails.application.config.session_options
end
