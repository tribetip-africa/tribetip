# frozen_string_literal: true

namespace :db do
  namespace :replica do
    desc "Create and load schema on the development replica database (when DB_REPLICA_DATABASE differs from primary)"
    task prepare: :environment do
      unless Rails.env.development?
        abort "db:replica:prepare is only for development"
      end

      primary_db = ENV.fetch("DB_DATABASE", "tribetip_development")
      replica_db = ENV.fetch("DB_REPLICA_DATABASE", primary_db)

      if replica_db == primary_db
        puts "DB_REPLICA_DATABASE matches primary (#{primary_db}); no separate replica DB to prepare."
        next
      end

      config = ActiveRecord::Base.configurations.configs_for(env_name: "development", name: "primary_replica")
      ActiveRecord::Tasks::DatabaseTasks.create(config)
      ActiveRecord::Tasks::DatabaseTasks.load_schema(config)
      puts "Prepared replica database: #{replica_db}"
    end
  end
end
