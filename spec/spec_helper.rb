require 'bundler'
require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

Bundler.require(:default, :development)

require './configuration'
require './test_database'

require 'departure'
require 'lhm'

require 'support/matchers/have_column'
require 'support/matchers/have_index'
require 'support/matchers/have_foreign_key_on'
require 'support/shared_examples/column_definition_method'
require 'support/table_methods'

db_config = Configuration.new

begin
  require 'activerecord-trilogy-adapter'
rescue LoadError => e
  puts "'activerecord-trilogy-adapter' not loaded for #{Rails.version}"
end

# Disables/enables the queries log you see in your rails server in dev mode
fd = ENV['VERBOSE'] ? STDOUT : '/dev/null'
ActiveRecord::Base.logger = Logger.new(fd)

ActiveRecord::Base.establish_connection(
  adapter: 'percona',
  original_adapter: db_config['original_adapter'],
  host: db_config['hostname'],
  username: db_config['username'],
  password: db_config['password'],
  database: db_config['database'],
  ssl_mode: 'required'
)

MIGRATION_FIXTURES = File.expand_path('../fixtures/migrate/', __FILE__)

test_database = TestDatabase.new(db_config)

RSpec.configure do |config|
  config.include TableMethods
  config.filter_run_when_matching :focus

  ActiveRecord::Migration.verbose = false

  # Needs an empty block to initialize the config with the default values
  Departure.configure do |_config|
  end

  # Cleans up the database before each example, so the current example doesn't
  # see the state of the previous one
  config.before(:each) do |example|
    if example.metadata[:integration]
      test_database.setup
      ActiveRecord::Base.connection_pool.disconnect!
    end
  end

  config.order = :random

  Kernel.srand config.seed
end

# This shim is for Rails 7.1 compatibility in the test
module Rails7Compatibility
  module MigrationContext
    def initialize(migrations_paths, schema_migration = nil)
      super(migrations_paths)
    end
  end
end

if ActiveRecord::VERSION::STRING >= '7.1'
  ActiveRecord::MigrationContext.send :prepend, Rails7Compatibility::MigrationContext
end
