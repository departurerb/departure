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

require 'departure/railtie' if defined?(Rails)

# We need the OS not to buffer the IO to see pt-osc's output while migrating
$stdout.sync = true

module Departure
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  # Hooks Percona Migrator into Rails migrations by replacing the configured
  # database adapter
  def self.load
    ActiveRecord::Migration.class_eval do
      alias_method :original_migrate, :migrate

      def self.migrate_offline
        class_eval do
          def migrate_offline?
            true
          end
        end
      end

      # Replaces the current connection adapter with the PerconaAdapter and
      # patches LHM, then it continues with the regular migration process.
      #
      # @param direction [Symbol] :up or :down
      def migrate(direction)
        establish_adapter_connection

        original_migrate(direction)
      end

      def establish_adapter_connection
        try(:migrate_offline?) ? use_mysql2_adapter : use_percona_adapter
      end
    end

    add_percona_helpers
    add_mysql2_helpers
  end

  def self.add_percona_helpers
    ActiveRecord::Migration.class_eval do
      # Includes the Foreigner's Mysql2Adapter implemention in
      # DepartureAdapter to support foreign keys
      def include_foreigner
        Foreigner::Adapter.safe_include(
          :DepartureAdapter,
          Foreigner::ConnectionAdapters::Mysql2Adapter
        )
      end

      def use_percona_adapter
        reconnect_with_percona
        include_foreigner if defined?(Foreigner)
        ::Lhm.migration = self
      end

      # Make all connections in the connection pool to use PerconaAdapter
      # instead of the current adapter.
      def reconnect_with_percona
        connection_config = ActiveRecord::Base
          .connection_config.merge(adapter: 'percona')
        Departure::ConnectionBase.establish_connection(connection_config)
      end
    end
  end

  def self.add_mysql2_helpers
    ActiveRecord::Migration.class_eval do
      def use_mysql2_adapter
        reconnect_with_mysql2 unless connected_with_mysql2?
      end

      # Make all connections in the connection pool to use Mysql2 adapter
      # instead of the percona adapter.
      def reconnect_with_mysql2
        connection_config = ActiveRecord::Base
          .connection_config.merge(adapter: 'mysql2')
        Departure::ConnectionOfflineBase.establish_connection(connection_config)
      end

      def connected_with_mysql2?
        ActiveRecord::Base.connection.adapter_name.downcase == 'mysql2'
      end
    end
  end
end
