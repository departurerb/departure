require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

require './configuration'
require 'departure'
require './test_database'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :db do
  desc 'Create the test database'
  task :create do
    config = Configuration.new
    TestDatabase.new(config).setup_test_database
  end
end
