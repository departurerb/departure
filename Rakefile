require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

require 'logger'
require './configuration'
require './test_database'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :db do
  desc 'Create the test database'
  task :create do
    config = Configuration.new

    ActiveRecord::Base.establish_connection(
      adapter: 'mysql2',
      host: config['hostname'],
      username: config['username'],
      password: config['password']
    )

    TestDatabase.new(config).setup_test_database
  end
end
