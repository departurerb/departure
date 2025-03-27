MIGRATION_FIXTURES = File.expand_path('../dummy/db/migrate', __dir__)

def establish_percona_connection
  ActiveRecord::Base.establish_connection(
    adapter: 'percona',
    host: db_config['hostname'],
    username: db_config['username'],
    password: db_config['password'],
    database: db_config['database']
  )
end

def establish_mysql_connection
  db_config = Configuration.new

  ActiveRecord::Base.establish_connection(
    adapter: 'mysql2',
    host: db_config['hostname'],
    username: db_config['username'],
    password: db_config['password'],
    database: db_config['database']
  )
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
