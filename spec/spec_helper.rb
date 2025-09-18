require 'simplecov'
SimpleCov.start

ENV['RAILS_ENV'] ||= 'development'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'bundler/setup'
Bundler.require(:default, :development)

require 'support/constants'
require './configuration'
require './test_database'

require 'departure'
require 'lhm'

require 'support/matchers/have_column'
require 'support/matchers/have_index'
require 'support/matchers/have_foreign_key_on'
require 'support/shared_examples/column_definition_method'
require 'support/table_methods'
require 'support/database_helpers'

db_config = Configuration.new

# Disables/enables the queries log you see in your rails server in dev mode
fd = ENV['VERBOSE'] ? STDOUT : '/dev/null'
ActiveRecord::Base.logger = Logger.new(fd)

test_database = TestDatabase.new(db_config)

Departure::RailsAdapter.for_current.register_integrations

RSpec.configure do |config|
  config.include TableMethods
  config.filter_run_when_matching :focus

  ActiveRecord::Migration.verbose = false

  # Needs an empty block to initialize the config with the default values
  Departure.configure do |_config|
  end

  config.define_derived_metadata(:activerecord_compatibility) do |meta|
    unless Departure::RailsAdapter.version_matches?(ActiveRecord::VERSION::STRING, meta[:activerecord_compatibility])
      meta[:skip] =
        "Spec defines behavior not compatible with #{ActiveRecord::VERSION::STRING}\
        , requires '#{meta[:activerecord_compatibility]}'"
    end
  end

  # Cleans up the database before each example, so the current example doesn't
  # see the state of the previous one
  config.before(:each) do |example|
    establish_mysql_connection

    test_database.setup if example.metadata[:integration]
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
