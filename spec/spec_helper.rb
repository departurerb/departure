require 'bundler'
require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

Bundler.require(:default, :development)

require './configuration'

require 'departure'
require 'lhm'

require './test_database'

require 'support/matchers/have_column'
require 'support/matchers/have_index'
require 'support/matchers/have_foreign_key_on'
require 'support/shared_examples/column_definition_method'
require 'support/table_methods'
require 'support/adapter_methods'

db_config = Configuration.new

# Disables/enables the queries log you see in your rails server in dev mode
fd = ENV['VERBOSE'] ? STDOUT : '/dev/null'
ActiveRecord::Base.logger = Logger.new(fd)

ActiveRecord::Base.establish_connection(
  adapter: 'percona',
  original_adapter: db_config['original_adapter'],
  host: db_config['hostname'],
  username: db_config['username'],
  password: db_config['password'],
  database: db_config['database']
)

MIGRATION_FIXTURES = File.expand_path('../fixtures/migrate/', __FILE__)

test_database = TestDatabase.new(db_config)

RSpec.configure do |config|
  config.include TableMethods
  config.include AdapterMethods
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

  # Around callback that runs the example only if the adapter option matches the
  # current adapter that is defined in the database configuration
  # Usage example:
  # describe MyClass do
  #   context "when doing this" do
  #     it "does that", adapter: :mysql do
  #       # This example will only run if the adapter is set to 'mysql'
  #     end
  #
  #     it "does that", adapter: :trilogy do
  #       # This example will only run if the adapter is set to 'trilogy'
  #     end
  #   end
  # end
  config.around(:each) do |example|
    adapter_option = example.metadata[:adapter]
    if adapter_option.present?
      if adapter_option.to_s == db_config['original_adapter']
        example.run
      else
        skip("Ignoring this example, since it will only run for '#{adapter_option}' adapter")
      end
    else
      example.run
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
