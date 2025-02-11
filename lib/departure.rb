require 'active_record'
require 'active_support/all'

require 'active_record/connection_adapters/for_alter'

require 'departure/version'
require 'departure/adapter_extensions/trilogy'
require 'departure/adapter_extensions/mysql2'
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

require 'departure/railtie' if defined?(Rails)

# We need the OS not to buffer the IO to see pt-osc's output while migrating
$stdout.sync = true

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.class_eval do
    include Departure::Migration
  end
end

module Departure
  SUPPORTED_ADAPTERS = %w[trilogy mysql2].freeze

  class << self
    attr_accessor :configuration

    def connection_method(adapter)
      return "#{adapter}_connection" if Departure::SUPPORTED_ADAPTERS.include?(adapter)

      if adapter.blank?
        raise ArgumentError, 'You must supply the original_adapter when connecting ' \
                            "using the percona adapter. Supported adapters: #{SUPPORTED_ADAPTERS}"
      end

      raise ArgumentError, "Unsupported adapter #{adapter}. Supported Departure " \
                            "adapters are #{Departure::SUPPORTED_ADAPTERS.inspect}"
    end
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  def self.load
    # No-op left for compatibility
  end
end
