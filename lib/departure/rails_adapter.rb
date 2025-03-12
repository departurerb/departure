# frozen_string_literal: true

module Departure
  class RailsAdapter
    extend Forwardable

    class << self
      def current_version
        ActiveRecord::VERSION
      end

      def for_current
        self.for(current_version)
      end

      def for(ar_version)
        raise 'Not supported yet' if ar_version::MAJOR >= 7 && ar_version::MINOR >= 2

        # V7_2

        BaseAdapter
      end
    end

    class BaseAdapter
      class << self
        def register_integrations
          require 'active_record/connection_adapters/percona_adapter'

          ActiveSupport.on_load(:active_record) do
            ActiveRecord::Migration.class_eval do
              include Departure::Migration
            end
          end
        end

        # ActiveRecord::ConnectionAdapters::Mysql2Adapter
        def create_connection_adapter(**config)
          mysql2_adapter = ActiveRecord::Base.mysql2_connection(config)

          connection_details = Departure::ConnectionDetails.new(config)
          verbose = ActiveRecord::Migration.verbose
          sanitizers = [
            Departure::LogSanitizers::PasswordSanitizer.new(connection_details)
          ]
          percona_logger = Departure::LoggerFactory.build(sanitizers: sanitizers, verbose: verbose)
          cli_generator = Departure::CliGenerator.new(connection_details)

          runner = Departure::Runner.new(
            percona_logger,
            cli_generator,
            mysql2_adapter
          )

          connection_options = { mysql_adapter: mysql2_adapter }

          ActiveRecord::ConnectionAdapters::DepartureAdapter.new(
            runner,
            percona_logger,
            connection_options,
            config
          )
        end
      end
    end
  end
end
