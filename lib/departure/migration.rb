module Departure
  # Hooks Departure into Rails migrations by replacing the configured database
  # adapter.
  #
  # It also patches ActiveRecord's #migrate method so that it patches LHM
  # first. This will make migrations written with LHM to go through the
  # regular Rails Migration DSL.
  module Migration
    extend ActiveSupport::Concern

    DEPARTURE_ADAPTERS = %w[percona percona_trilogy].freeze

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
      with_restored_connection_specification_name do
        if uses_departure?
          departure_migrate(direction)
        else
          reconnect_without_percona
          active_record_migrate(direction)
        end
      end
    end

    # Includes the Foreigner's Mysql2Adapter implemention in
    # DepartureAdapter to support foreign keys
    def include_foreigner
      Foreigner::Adapter.safe_include(
        :DepartureAdapter,
        Foreigner::ConnectionAdapters::Mysql2Adapter
      )
    end

    # Make all connections in the connection pool to use PerconaAdapter
    # instead of the current adapter.
    def reconnect_with_percona
      config = connection_config
      return if departure_adapter_config?(config)

      departure_adapter = Departure::RailsAdapter.for_current(db_connection_adapter: config[:adapter])
      Departure::ConnectionBase.establish_connection(
        config.merge(
          adapter: departure_adapter.departure_adapter_name,
          departure_original_adapter: config[:adapter]
        )
      )
    end

    # Reconnect without percona adapter when Departure is disabled but was
    # enabled in a previous migration.
    def reconnect_without_percona
      config = connection_config
      return unless departure_adapter_config?(config)

      Departure::OriginalAdapterConnection.establish_connection(
        config
          .except(:departure_original_adapter)
          .merge(adapter: config[:departure_original_adapter] || original_adapter)
      )
    end

    private

    # Capture the type of the adapter configured by the app if not already set.
    def connection_config
      configuration_hash.tap do |config|
        self.class.original_adapter ||= config[:departure_original_adapter] || config[:adapter]
      end
    end

    private def departure_adapter_config?(config)
      DEPARTURE_ADAPTERS.include?(config[:adapter])
    end

    private def configuration_hash
      ActiveRecord::Base.connection_db_config.configuration_hash
    end

    private def with_restored_connection_specification_name
      connection_specification_name = ActiveRecord::Base.connection_specification_name

      yield
    ensure
      ActiveRecord::Base.connection_specification_name = connection_specification_name
    end
  end
end
