require 'bundler'
require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

Bundler.require(:default, :development)

require './configuration'
require './test_database'

require 'departure'
require 'lhm'

require 'support/matchers/have_column'
require 'support/matchers/have_index'
require 'support/matchers/have_foreign_key_on'
require 'support/table_methods'

db_config = Configuration.new

# Disables/enables the queries log you see in your rails server in dev mode
fd = ENV['VERBOSE'] ? $stdout : '/dev/null'
ActiveRecord::Base.logger = Logger.new(fd)

ActiveRecord::Base.establish_connection(
  adapter: 'percona',
  host: db_config['hostname'],
  username: db_config['username'],
  password: db_config['password'],
  database: db_config['database']
)

MIGRATION_FIXTURES = File.expand_path('fixtures/migrate', __dir__)

test_database = TestDatabase.new(db_config)

class Comment < ActiveRecord::Base; end

RSpec.configure do |config|
  config.include TableMethods
  config.filter_run_when_matching :focus

  ActiveRecord::Migration.verbose = false

  # Needs an empty block to initialize the config with the default values
  Departure.configure do |_config| # rubocop:disable Lint/EmptyBlock
  end

  # Cleans up the database before each example, so the current example doesn't
  # see the state of the previous one
  config.before(:each) do |example|
    test_database.setup if example.metadata[:integration]
  end

  config.order = :random

  Kernel.srand config.seed
end

# This shim is for Rails 5.2 compatibility in the test
module Rails5Compatibility
  module Migrator
    def initialize(direction, migrations, schema_migration_or_target_version = nil, target_version = nil)
      if schema_migration_or_target_version == ActiveRecord::SchemaMigration
        super(direction, migrations, target_version)
      else
        super(direction, migrations, schema_migration_or_target_version)
      end
    end
  end

  module MigrationContext
    def initialize(migrations_paths, _schema_migration = nil)
      super(migrations_paths)
    end
  end
end

if ActiveRecord::VERSION::MAJOR < 6
  ActiveRecord::Migrator.prepend Rails5Compatibility::Migrator
  ActiveRecord::MigrationContext.prepend Rails5Compatibility::MigrationContext
end
