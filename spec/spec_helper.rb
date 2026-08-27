require "simplecov"
SimpleCov.start

ENV["RAILS_ENV"] ||= "test"

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "bundler/setup"
require "climate_control"
require "rspec/its"

require_relative "dummy/config/environment"

require "departure"
require "lhm"

require "support/constants"
require "support/matchers/have_column"
require "support/matchers/have_index"
require "support/matchers/have_foreign_key_on"
require "support/shared_examples/column_definition_method"
require "support/table_methods"
require "support/database_helpers"
require "support/test_database"

test_database = TestDatabase.new(app_database_config)

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
    establish_default_database_connection

    if example.metadata[:integration]
      test_database.setup
    end
  end

  config.order = :random

  Kernel.srand config.seed
end

# This shim is for Rails 7.1 compatibility in the test
module Rails7Compatibility
  module MigrationContext
    def initialize(migrations_paths, schema_migration = nil, internal_metadata = nil)
      if schema_migration.is_a?(Class)
        super(migrations_paths)
      else
        super
      end
    end
  end
end

if ActiveRecord::VERSION::STRING >= "7.1"
  ActiveRecord::MigrationContext.send :prepend, Rails7Compatibility::MigrationContext
end

def rails_version_under_test_matches?(version_string, file)
  Departure::RailsAdapter.version_matches?(ActiveRecord::VERSION::STRING, version_string).tap do |result|
    unless result
      error = "Skip #{file} test - current '#{version_string}' not matching version #{ActiveRecord::VERSION::STRING}"

      puts ""
      puts "-- *** INFO ****"
      puts "-- #{error}"
      puts ""
    end
  end
end
