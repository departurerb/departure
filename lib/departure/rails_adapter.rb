# frozen_string_literal: true

require "forwardable"

module Departure
  class RailsAdapter
    extend ::Forwardable

    class UnsupportedRailsVersionError < StandardError; end
    class MustImplementError < StandardError; end

    # Describes how a Departure connection adapter is registered with
    # ActiveRecord: the adapter name apps configure, the class implementing it
    # and the file that defines the class.
    Registration = Struct.new(:adapter_name, :class_name, :path)

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

      def for(ar_version, db_connection_adapter: nil)
        adapters =
          if ar_version::MAJOR == 8 && ar_version::MINOR.positive?
            {mysql2: V8_1_Mysql2Adapter, trilogy: V8_1_TrilogyAdapter}
          elsif ar_version::MAJOR == 8
            {mysql2: V8_0_Adapter, trilogy: V8_0_TrilogyAdapter}
          elsif ar_version::MAJOR >= 7 && ar_version::MINOR >= 2
            {mysql2: V7_2_Adapter, trilogy: V7_2_TrilogyAdapter}
          else
            raise UnsupportedRailsVersionError, "Unsupported Rails version: #{ar_version}"
          end

        (db_connection_adapter == "trilogy") ? adapters[:trilogy] : adapters[:mysql2]
      end
    end

    class BaseAdapter
      class << self
        # The Registration for the database adapter this class drives.
        # Subclasses must implement it.
        def registration
          raise MustImplementError, "adapter must implement registration"
        end

        # Every Registration available for this Rails version, so all
        # Departure adapter names resolve regardless of which one the app
        # connects through. Registration is lazy: the adapter files are only
        # loaded when ActiveRecord resolves the adapter name.
        # Subclasses must implement it.
        def registrations
          raise MustImplementError, "adapter must implement registrations"
        end

        def register_integrations
          require registration.path
          require "departure/rails_patches/active_record_migrator_with_advisory_lock_patch"

          ActiveRecord::Migration.class_eval do
            include Departure::Migration
          end

          ActiveRecord::Migrator.prepend Departure::RailsPatches::ActiveRecordMigratorWithAdvisoryLockPatch

          registrations.each do |registration|
            ActiveRecord::ConnectionAdapters.register registration.adapter_name,
              registration.class_name,
              registration.path
          end
        end

        def create_connection_adapter(**config)
          connection_adapter_class.new(config)
        end

        def departure_adapter_name
          registration.adapter_name
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
          connection_adapter_class::Column
        end

        private

        def connection_adapter_class
          require registration.path

          Object.const_get(registration.class_name)
        end
      end
    end

    class V7_2_Adapter < BaseAdapter # rubocop:disable Naming/ClassAndModuleCamelCase
      MYSQL2_REGISTRATION = Registration.new(
        "percona",
        "ActiveRecord::ConnectionAdapters::Rails72DepartureAdapter",
        "active_record/connection_adapters/rails_7_2_departure_adapter"
      )
      TRILOGY_REGISTRATION = Registration.new(
        "percona_trilogy",
        "ActiveRecord::ConnectionAdapters::Rails72TrilogyAdapter",
        "active_record/connection_adapters/rails_7_2_trilogy_adapter"
      )

      class << self
        def registration
          MYSQL2_REGISTRATION
        end

        def registrations
          [MYSQL2_REGISTRATION, TRILOGY_REGISTRATION]
        end
      end
    end

    class V7_2_TrilogyAdapter < V7_2_Adapter # rubocop:disable Naming/ClassAndModuleCamelCase
      # def self so TRILOGY_REGISTRATION resolves through the superclass
      def self.registration
        TRILOGY_REGISTRATION
      end
    end

    class V8_0_Adapter < BaseAdapter # rubocop:disable Naming/ClassAndModuleCamelCase
      MYSQL2_REGISTRATION = Registration.new(
        "percona",
        "ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter",
        "active_record/connection_adapters/rails_8_0_departure_adapter"
      )
      TRILOGY_REGISTRATION = Registration.new(
        "percona_trilogy",
        "ActiveRecord::ConnectionAdapters::Rails80TrilogyAdapter",
        "active_record/connection_adapters/rails_8_0_trilogy_adapter"
      )

      class << self
        def registration
          MYSQL2_REGISTRATION
        end

        def registrations
          [MYSQL2_REGISTRATION, TRILOGY_REGISTRATION]
        end
      end
    end

    class V8_0_TrilogyAdapter < V8_0_Adapter # rubocop:disable Naming/ClassAndModuleCamelCase
      # def self so TRILOGY_REGISTRATION resolves through the superclass
      def self.registration
        TRILOGY_REGISTRATION
      end
    end

    class V8_1_Mysql2Adapter < BaseAdapter # rubocop:disable Naming/ClassAndModuleCamelCase
      MYSQL2_REGISTRATION = Registration.new(
        "percona",
        "ActiveRecord::ConnectionAdapters::Rails81Mysql2Adapter",
        "active_record/connection_adapters/rails_8_1_mysql2_adapter"
      )
      TRILOGY_REGISTRATION = Registration.new(
        "percona_trilogy",
        "ActiveRecord::ConnectionAdapters::Rails81TrilogyAdapter",
        "active_record/connection_adapters/rails_8_1_trilogy_adapter"
      )

      class << self
        def registration
          MYSQL2_REGISTRATION
        end

        def registrations
          [MYSQL2_REGISTRATION, TRILOGY_REGISTRATION]
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
      # def self so TRILOGY_REGISTRATION resolves through the superclass
      def self.registration
        TRILOGY_REGISTRATION
      end
    end
  end
end
