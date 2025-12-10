# frozen_string_literal: true

require 'forwardable'

module Departure
  class RailsAdapter
    extend ::Forwardable

    class UnsupportedRailsVersionError < StandardError; end
    class MustImplementError < StandardError; end

    class << self
      def register_integrations(**args)
        for_current(**args).register_integrations
      end

      def version_matches?(version_string, compatibility_string = current_version::STRING)
        raise "Invalid Gem Version: '#{version_string}'" unless Gem::Version.correct?(version_string)

        requirement = Gem::Requirement.new(compatibility_string)
        requirement.satisfied_by?(Gem::Version.new(version_string))
      end

      def current_version
        ActiveRecord::VERSION
      end

      def for_current(**args)
        self.for(current_version, **args)
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def for(ar_version, db_connection_adapter: nil)
        # rubocop:enable Metrics/PerceivedComplexity
        if ar_version::MAJOR == 8 && ar_version::MINOR.positive?
          if db_connection_adapter == 'trilogy'
            V8_1_TrilogyAdapter
          else
            V8_1_Mysql2Adapter
          end
        elsif ar_version::MAJOR == 8
          V8_0_Adapter
        elsif ar_version::MAJOR >= 7 && ar_version::MINOR >= 2
          V7_2_Adapter
        else
          raise UnsupportedRailsVersionError, "Unsupported Rails version: #{ar_version}"
        end
      end
    end

    class BaseAdapter
      class << self
        def register_integrations
          raise MustImplementError, 'adapter must implement register_integrations'
        end

        # ActiveRecord::ConnectionAdapters::Mysql2Adapter
        def create_connection_adapter(**_config)
          raise MustImplementError, 'adapter must implement create_connection_adapter'
        end

        # https://github.com/rails/rails/commit/9ad36e067222478090b36a985090475bb03e398c#diff-de807ece2205a84c0e3de66b0e5ab831325d567893b8b88ce0d6e9d498f923d1
        # Rails Column arity changed to require cast_type in position 2 which required us introducing this indirection
        def new_sql_column(name:,
                           default_value:,
                           mysql_metadata:,
                           null_value:,
                           **_kwargs)
          sql_column.new(name, default_value, mysql_metadata, null_value)
        end

        def sql_column
          ::ActiveRecord::ConnectionAdapters::DepartureAdapter::Column
        end
      end
    end

    class V7_2_Adapter < BaseAdapter # rubocop:disable Naming/ClassAndModuleCamelCase
      class << self
        def register_integrations
          require 'active_record/connection_adapters/rails_7_2_departure_adapter'
          require 'departure/rails_patches/active_record_migrator_with_advisory_lock_patch'

          ActiveRecord::Migration.class_eval do
            include Departure::Migration
          end

          ActiveRecord::Migrator.prepend Departure::RailsPatches::ActiveRecordMigratorWithAdvisoryLockPatch

          ActiveRecord::ConnectionAdapters.register 'percona',
                                                    'ActiveRecord::ConnectionAdapters::Rails72DepartureAdapter',
                                                    'active_record/connection_adapters/rails_7_2_departure_adapter'
        end

        def create_connection_adapter(**config)
          ActiveRecord::ConnectionAdapters::Rails72DepartureAdapter.new(config)
        end

        def sql_column
          ::ActiveRecord::ConnectionAdapters::Rails72DepartureAdapter::Column
        end
      end
    end

    class V8_0_Adapter < BaseAdapter # rubocop:disable Naming/ClassAndModuleCamelCase
      class << self
        def register_integrations
          require 'active_record/connection_adapters/rails_8_0_departure_adapter'
          require 'departure/rails_patches/active_record_migrator_with_advisory_lock_patch'

          ActiveRecord::Migration.class_eval do
            include Departure::Migration
          end

          ActiveRecord::Migrator.prepend Departure::RailsPatches::ActiveRecordMigratorWithAdvisoryLockPatch

          ActiveRecord::ConnectionAdapters.register 'percona',
                                                    'ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter',
                                                    'active_record/connection_adapters/rails_8_0_departure_adapter'
        end

        def create_connection_adapter(**config)
          ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter.new(config)
        end

        def sql_column
          ::ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter::Column
        end
      end
    end

    class V8_1_Mysql2Adapter < BaseAdapter # rubocop:disable Naming/ClassAndModuleCamelCase
      class << self
        def register_integrations
          require 'active_record/connection_adapters/rails_8_1_mysql2_adapter'
          require 'departure/rails_patches/active_record_migrator_with_advisory_lock_patch'

          ActiveRecord::Migration.class_eval do
            include Departure::Migration
          end

          ActiveRecord::Migrator.prepend Departure::RailsPatches::ActiveRecordMigratorWithAdvisoryLockPatch

          ActiveRecord::ConnectionAdapters.register 'percona',
                                                    'ActiveRecord::ConnectionAdapters::Rails81Mysql2Adapter',
                                                    'active_record/connection_adapters/rails_8_1_mysql2_adapter'
        end

        def create_connection_adapter(**config)
          ActiveRecord::ConnectionAdapters::Rails81Mysql2Adapter.new(config)
        end

        # rubocop:disable Metrics/ParameterLists
        # https://github.com/rails/rails/commit/9ad36e067222478090b36a985090475bb03e398c#diff-de807ece2205a84c0e3de66b0e5ab831325d567893b8b88ce0d6e9d498f923d1
        # Rails Column arity changed to require cast_type in position 2 which required us introducing this indirection
        def new_sql_column(name:,
                           cast_type:,
                           default_value:,
                           mysql_metadata:,
                           null_value:,
                           **_kwargs)
          # rubocop:enable Metrics/ParameterLists
          sql_column.new(name, cast_type, default_value, mysql_metadata, null_value)
        end

        def sql_column
          ::ActiveRecord::ConnectionAdapters::MySQL::Column
        end
      end
    end

    class V8_1_TrilogyAdapter < V8_1_Mysql2Adapter # rubocop:disable Naming/ClassAndModuleCamelCase
      class << self
        def register_integrations
          require 'active_record/connection_adapters/rails_8_1_trilogy_adapter'
          require 'departure/rails_patches/active_record_migrator_with_advisory_lock_patch'

          ActiveRecord::Migration.class_eval do
            include Departure::Migration
          end

          ActiveRecord::Migrator.prepend Departure::RailsPatches::ActiveRecordMigratorWithAdvisoryLockPatch

          ActiveRecord::ConnectionAdapters.register 'percona',
                                                    'ActiveRecord::ConnectionAdapters::Rails81TrilogyAdapter',
                                                    'active_record/connection_adapters/rails_8_1_trilogy_adapter'
        end

        def create_connection_adapter(**config)
          ActiveRecord::ConnectionAdapters::Rails81TrilogyAdapter.new(config)
        end
      end
    end
  end
end
