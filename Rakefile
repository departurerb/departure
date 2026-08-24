require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :db do
  desc "Create the test database"
  task :create do
    require_relative "spec/dummy/config/application"

    Rails.application.initialize!
    ActiveRecord::Tasks::DatabaseTasks.create_current
  end
end
