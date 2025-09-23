MIGRATION_FIXTURES = File.expand_path('../dummy/db/migrate', __dir__)

def db_config_for(adapter:)
  db_config = Configuration.new

  {
    adapter:,
    **db_config.config
  }
end

def establish_default_database_connection
  case ENV['DB_ADAPTER']
  when 'trilogy'
    establish_trilogy_connection
  when 'percona'
    establish_percona_connection
  else
    establish_mysql_connection
  end
end

def establish_trilogy_connection
  ActiveRecord::Base.establish_connection(**db_config_for(adapter: 'trilogy'))
end

def establish_percona_connection
  ActiveRecord::Base.establish_connection(**db_config_for(adapter: 'percona'))
end

def establish_mysql_connection
  ActiveRecord::Base.establish_connection(**db_config_for(adapter: 'mysql2'))
end

def setup_departure_integrations
  Departure::RailsAdapter.for_current.register_integrations
end

def disable_departure_rails_advisory_lock_patch
  Departure.configure do |config|
    config.disable_rails_advisory_lock_patch = true
  end
end

def enable_departure_rails_advisory_lock_patch
  Departure.configure do |config|
    config.disable_rails_advisory_lock_patch = false
  end
end

def migration_context
  ActiveRecord::MigrationContext.new([MIGRATION_FIXTURES], ActiveRecord::SchemaMigration)
end

def run_a_migration(direction, target_version)
  migration_context.run(direction, target_version)
end

def current_migration_version
  migration_context.current_version
end
