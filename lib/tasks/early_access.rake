# frozen_string_literal: true

namespace :early_access do
  desc "Create an early access invite for EMAIL (optional EXPIRES_IN_DAYS)"
  task :invite, [ :email ] => :environment do |_t, args|
    email = args[:email].presence || ENV["EMAIL"]
    abort "Usage: bin/rails early_access:invite[email@example.com]" if email.blank?

    expires = ENV["EXPIRES_IN_DAYS"]
    invite = Tribetip::EarlyAccess::Invites.create!(
      email: email,
      expires_in_days: expires
    )

    puts "Invite created for #{invite.email}"
    puts "Token: #{invite.token}"
    puts "URL:   #{Tribetip::EarlyAccess::Invites.url_for(invite.token)}"
    puts "Expires: #{invite.expires_at.iso8601}"
  end
end
