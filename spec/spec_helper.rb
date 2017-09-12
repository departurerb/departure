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
require 'support/table_methods'

db_config = Configuration.new

# Disables/enables the queries log you see in your rails server in dev mode
fd = ENV['VERBOSE'] ? STDOUT : '/dev/null'
ActiveRecord::Base.logger = Logger.new(fd)

ActiveRecord::Base.establish_connection(
  adapter: 'percona',
  host: db_config['hostname'],
  username: db_config['username'],
  password: db_config['password'],
  database: db_config['database']
)

MIGRATION_FIXTURES = File.expand_path('../fixtures/migrate/', __FILE__)

test_database = TestDatabase.new(db_config)

RSpec.configure do |config|
  config.include TableMethods

  ActiveRecord::Migration.verbose = false

  # Needs an empty block to initialize the config with the default values
  Departure.configure do |_config|
  end

  # Cleans up the database before each example, so the current example doesn't
  # see the state of the previous one
  config.before(:each) do |example|
    test_database.setup if example.metadata[:integration]
  end

  config.order = :random

  Kernel.srand config.seed
end
