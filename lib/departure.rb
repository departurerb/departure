require 'active_record'
require 'active_support/all'

require 'active_record/connection_adapters/for_alter'

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
require 'departure/rails_integrator'

require 'departure/railtie' if defined?(Rails)

# We need the OS not to buffer the IO to see pt-osc's output while migrating
$stdout.sync = true

Departure::RailsIntegrator.for_current.register_integrations

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
