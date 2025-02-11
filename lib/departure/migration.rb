module Departure
  # Hooks Departure into Rails migrations by replacing the configured database
  # adapter.
  #
  # It also patches ActiveRecord's #migrate method so that it patches LHM
  # first. This will make migrations written with LHM to go through the
  # regular Rails Migration DSL.
  module Migration
    extend ActiveSupport::Concern

    included do
      # Holds the name of the adapter that was configured by the app.
      mattr_accessor :original_adapter

      # Declare on a per-migration class basis whether or not to use Departure.
      # The default for this attribute is set based on
      # Departure.configuration.enabled_by_default (default true).
      class_attribute :uses_departure
      self.uses_departure = true

      alias_method :active_record_migrate, :migrate
      remove_method :migrate
    end

    module ClassMethods
      # Declare `uses_departure!` in the class body of your migration to enable
      # Departure for that migration only when
      # Departure.configuration.enabled_by_default is false.
      def uses_departure!
        self.uses_departure = true
      end

      # Declare `disable_departure!` in the class body of your migration to
      # disable Departure for that migration only (when
      # Departure.configuration.enabled_by_default is true, the default).
      def disable_departure!
        self.uses_departure = false
      end
    end

    # Replaces the current connection adapter with the PerconaAdapter and
    # patches LHM, then it continues with the regular migration process.
    #
    # @param direction [Symbol] :up or :down
    def departure_migrate(direction)
      reconnect_with_percona
      include_foreigner if defined?(Foreigner)

      ::Lhm.migration = self
      active_record_migrate(direction)
    end

    # Migrate with or without Departure based on uses_departure class
    # attribute.
    def migrate(direction)
      if uses_departure?
        departure_migrate(direction)
      else
        reconnect_without_percona
        active_record_migrate(direction)
      end
    end

    # Includes the Foreigner's Mysql2Adapter implemention in
    # DepartureAdapter to support foreign keys
    #
    # Warning: Foreigner only works with MySQL2, and therefore
    #          trilogy is not supported
    def include_foreigner
      Foreigner::Adapter.safe_include(
        :DepartureAdapter,
        Foreigner::ConnectionAdapters::Mysql2Adapter
      )
    end

    # Make all connections in the connection pool to use PerconaAdapter
    # instead of the current adapter.
    def reconnect_with_percona
      return if connection_config[:adapter] == 'percona'
      Departure::ConnectionBase.establish_connection(connection_config.merge(adapter: 'percona',
                                                                             original_adapter: original_adapter))
    end

    # Reconnect without percona adapter when Departure is disabled but was
    # enabled in a previous migration.
    def reconnect_without_percona
      return unless connection_config[:adapter] == 'percona'
      Departure::OriginalAdapterConnection.establish_connection(connection_config.merge(adapter: original_adapter))
    end

    private

    # Capture the type of the adapter configured by the app if not already set.
    def connection_config
      configuration_hash.tap do |config|
        self.class.original_adapter ||= config[:adapter]
      end
    end

    private def configuration_hash
      if ActiveRecord::VERSION::STRING >= '6.1'
        ActiveRecord::Base.connection_db_config.configuration_hash
      else
        ActiveRecord::Base.connection_config
      end
    end
  end
end
