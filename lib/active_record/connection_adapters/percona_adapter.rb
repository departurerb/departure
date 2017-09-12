require 'active_record/connection_adapters/abstract_mysql_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'active_record/connection_adapters/mysql2_adapter'
require 'departure'
require 'forwardable'

module ActiveRecord
  module ConnectionHandling
    # Establishes a connection to the database that's used by all Active
    # Record objects.
    def percona_connection(config)
      mysql2_connection = mysql2_connection(config)

      config[:username] = 'root' if config[:username].nil?

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
        mysql2_connection
      )

      connection_options = { mysql_adapter: mysql2_connection }

      ConnectionAdapters::DepartureAdapter.new(
        runner,
        logger,
        connection_options,
        config
      )
    end
  end

  module ConnectionAdapters
    class DepartureAdapter < AbstractMysqlAdapter

      class Column < ActiveRecord::ConnectionAdapters::MySQL::Column
        def adapter
          DepartureAdapter
        end
      end

      extend Forwardable

      ADAPTER_NAME = 'Percona'.freeze

      def_delegators :mysql_adapter, :last_inserted_id, :each_hash, :set_field_encoding

      def initialize(connection, _logger, connection_options, _config)
        @mysql_adapter = connection_options[:mysql_adapter]
        super
        @prepared_statements = false
      end

      def exec_delete(sql, name, binds)
        execute(to_sql(sql, binds), name)
        @connection.affected_rows
      end
      alias exec_update exec_delete

      def exec_insert(sql, name, binds, pk = nil, sequence_name = nil) # rubocop:disable Lint/UnusedMethodArgument, Metrics/LineLength
        execute(to_sql(sql, binds), name)
      end

      def exec_query(sql, name = 'SQL', _binds = [])
        result = execute(sql, name)
        ActiveRecord::Result.new(result.fields, result.to_a)
      end

      # Executes a SELECT query and returns an array of rows. Each row is an
      # array of field values.

      def select_rows(arel, name = nil, binds = [])
        select_all(arel, name, binds).rows
      end

      # Executes a SELECT query and returns an array of record hashes with the
      # column names as keys and column values as values.
      def select(sql, name = nil, binds = [])
        exec_query(sql, name, binds)
      end

      # Returns true, as this adapter supports migrations
      def supports_migrations?
        true
      end

      # rubocop:disable Metrics/ParameterLists
      def new_column(field, default, type_metadata, null, table_name, default_function, collation, comment)
        Column.new(field, default, type_metadata, null, table_name, default_function, collation, comment)
      end
      # rubocop:enable Metrics/ParameterLists

      # Adds a new index to the table
      #
      # @param table_name [String, Symbol]
      # @param column_name [String, Symbol]
      # @param options [Hash] optional
      def add_index(table_name, column_name, options = {})
        index_name, index_type, index_columns, index_options = add_index_options(table_name, column_name, options)
        execute "ALTER TABLE #{quote_table_name(table_name)} ADD #{index_type} INDEX #{quote_column_name(index_name)} (#{index_columns})#{index_options}" # rubocop:disable Metrics/LineLength
      end

      # Remove the given index from the table.
      #
      # @param table_name [String, Symbol]
      # @param options [Hash] optional
      def remove_index(table_name, options = {})
        index_name = index_name_for_remove(table_name, options)
        execute "ALTER TABLE #{quote_table_name(table_name)} DROP INDEX #{quote_column_name(index_name)}"
      end

      # Returns the MySQL error number from the exception. The
      # AbstractMysqlAdapter requires it to be implemented
      def error_number(_exception); end

      def full_version
        mysql_adapter.raw_connection.server_info[:version]
      end

      private

      attr_reader :mysql_adapter
    end
  end
end
