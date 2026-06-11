# frozen_string_literal: true

# Idempotent development seeds. Re-run safely with: bin/rails db:seed
#
# Production: set TRIBETIP_SEED_ENABLED=true and TRIBETIP_SEED_PASSWORD=...

include_creators = ActiveModel::Type::Boolean.new.cast(ENV.fetch("TRIBETIP_SEED_CREATORS", "true"))

seeder = Tribetip::Seeds::Accounts.call(
  reset_password: ActiveModel::Type::Boolean.new.cast(ENV["TRIBETIP_SEED_RESET_PASSWORD"]),
  include_creators: include_creators
)

password_hint =
  if ENV["TRIBETIP_SEED_PASSWORD"].present?
    "(custom TRIBETIP_SEED_PASSWORD)"
  elsif Rails.env.production?
    "(TRIBETIP_SEED_PASSWORD)"
  else
    Tribetip::Seeds::Accounts::DEV_PASSWORD
  end

puts "\nTribeTip seed accounts (#{Rails.env})"
puts "Password for seeded accounts: #{password_hint}"
puts "-" * 60

Tribetip::Seeds::Accounts::ADMIN_ACCOUNTS.each do |account|
  puts "ADMIN  #{account[:username].ljust(16)} #{account[:email]}"
end

if include_creators
  Tribetip::Seeds::Accounts::CREATOR_ACCOUNTS.each do |account|
    state = [
      account[:onboarded] ? "onboarded" : "fresh",
      account[:published] ? "published" : "unpublished"
    ].join(", ")
    puts "CREATOR #{account[:username].ljust(15)} #{account[:email]} (#{state})"
  end
end

seeder.summary.each do |result|
  action =
    if result.skipped
      "unchanged"
    elsif result.created
      "created"
    else
      "updated"
    end
  puts "  -> #{result.key}: #{action}"
end

puts "-" * 60
puts "Sign in at /sign-in with email or username + password above.\n\n"
