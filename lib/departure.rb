require 'active_record'
require 'active_support/all'

require 'active_record/connection_adapters/for_alter'
require 'active_record/connection_adapters/percona_adapter'

require 'departure/version'
require 'departure/log_sanitizers/password_sanitizer'
require 'departure/runner'
require 'departure/cli_generator'
require 'departure/logger'
require 'departure/null_logger'
require 'departure/logger_factory'
require 'departure/configuration'
require 'departure/errors'
require 'departure/command'
require 'departure/connection_base'
require 'departure/migration'
require 'departure/migrator'

require 'departure/railtie' if defined?(Rails)

# We need the OS not to buffer the IO to see pt-osc's output while migrating
$stdout.sync = true

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.class_eval do
    include Departure::Migration
  end

  if ActiveRecord::VERSION::MAJOR >= 7 && ActiveRecord::VERSION::MINOR >= 1
    ActiveRecord::Migrator.class_eval do
      include Departure::Migrator
    end
  end
end

module Departure
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  def self.load
    # No-op left for compatibility
  end
end
