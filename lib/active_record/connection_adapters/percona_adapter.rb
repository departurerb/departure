require 'active_record/connection_adapters/abstract_mysql_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'active_record/connection_adapters/mysql2_adapter'
require 'active_support/core_ext/string/filters'
require 'departure'
require 'forwardable'

module ActiveRecord
  module ConnectionHandling
    # Establishes a connection to the database that's used by all Active
    # Record objects.
    def percona_connection(config)
      if config[:username].nil?
        config = config.dup if config.frozen?
        config[:username] = 'root'
      end

      if ActiveRecord::VERSION::MAJOR >= 7 && ActiveRecord::VERSION::MINOR >= 2
        ConnectionAdapters::DepartureAdapter.new(config)
      else
        mysql2_adapter = mysql2_connection(config)

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

        ConnectionAdapters::DepartureAdapter.new(
          runner,
          logger,
          connection_options,
          config
        )
      end
    end
  end

  module ConnectionAdapters
    if ActiveRecord::VERSION::MAJOR >= 7 && ActiveRecord::VERSION::MINOR >= 2
      register "percona", "ActiveRecord::ConnectionAdapters::DepartureAdapter", "active_record/connection_adapters/percona_adapter"
    end

    class DepartureAdapter < AbstractMysqlAdapter
      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) } if defined?(initialize_type_map)

      class Column < ActiveRecord::ConnectionAdapters::MySQL::Column
        def adapter
          DepartureAdapter
        end
      end

      class SchemaCreation < ActiveRecord::ConnectionAdapters::MySQL::SchemaCreation
        def visit_DropForeignKey(name) # rubocop:disable Style/MethodName
          fk_name =
            if name =~ /^__(.+)/
              Regexp.last_match(1)
            else
              "_#{name}"
            end

          "DROP FOREIGN KEY #{fk_name}"
        end
      end

      extend Forwardable

      unless method_defined?(:change_column_for_alter)
        include ForAlterStatements
      end

      ADAPTER_NAME = 'Percona'.freeze

      def_delegators :mysql_adapter, :each_hash, :set_field_encoding

      if ActiveRecord::VERSION::MAJOR >= 7 && ActiveRecord::VERSION::MINOR >= 2
        class << self
          def new_client(config)
            mysql2_adapter = ConnectionAdapters::Mysql2Adapter.new(config.merge(adapter: "mysql2"))

            connection_details = Departure::ConnectionDetails.new(config)
            verbose = ActiveRecord::Migration.verbose
            sanitizers = [
              Departure::LogSanitizers::PasswordSanitizer.new(connection_details)
            ]
            percona_logger = Departure::LoggerFactory.build(sanitizers: sanitizers, verbose: verbose)
            cli_generator = Departure::CliGenerator.new(connection_details)

            Departure::Runner.new(
              percona_logger,
              cli_generator,
              mysql2_adapter
            )
          end
        end

        def initialize(...)
          super

          @mysql_adapter = ConnectionAdapters::Mysql2Adapter.new(@config.merge(adapter: "mysql2"))

          @config[:flags] ||= 0

          if @config[:flags].kind_of? Array
            @config[:flags].push "FOUND_ROWS"
          else
            @config[:flags] |= ::Mysql2::Client::FOUND_ROWS
          end

          @connection_parameters ||= @config
        end
      else
        def initialize(connection, logger, connection_options, config)
          @mysql_adapter = connection_options[:mysql_adapter]
          super
          @prepared_statements = false
        end
      end

      def write_query?(sql) # :nodoc:
        !ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
          :desc, :describe, :set, :show, :use
        ).match?(sql)
      end

      def exec_delete(sql, name, binds)
        execute(to_sql(sql, binds), name)
        mysql_adapter.raw_connection.affected_rows
      end
      alias exec_update exec_delete

      def exec_insert(sql, name, binds, pk = nil, sequence_name = nil, returning: nil) # rubocop:disable Lint/UnusedMethodArgument, Metrics/LineLength, Metrics/ParameterLists
        execute(to_sql(sql, binds), name)
      end

      def internal_exec_query(sql, name = 'SQL', _binds = [], **_kwargs) # :nodoc:
        result = execute(sql, name)
        fields = result.fields if defined?(result.fields)
        ActiveRecord::Result.new(fields, result.to_a)
      end
      alias exec_query internal_exec_query

      # Executes a SELECT query and returns an array of rows. Each row is an
      # array of field values.

      def select_rows(arel, name = nil, binds = [])
        select_all(arel, name, binds).rows
      end

      # Executes a SELECT query and returns an array of record hashes with the
      # column names as keys and column values as values.
      def select(sql, name = nil, binds = [], **kwargs)
        exec_query(sql, name, binds, **kwargs)
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
        if ActiveRecord::VERSION::STRING >= '6.1'
          index_definition, = add_index_options(table_name, column_name, **options)
          execute <<-SQL.squish
            ALTER TABLE #{quote_table_name(index_definition.table)}
              ADD #{schema_creation.accept(index_definition)}
          SQL
        else
          index_name, index_type, index_columns, index_options = add_index_options(table_name, column_name, **options)
          execute <<-SQL.squish
            ALTER TABLE #{quote_table_name(table_name)}
              ADD #{index_type} INDEX
              #{quote_column_name(index_name)} (#{index_columns})#{index_options}
          SQL
        end
      end

      # Remove the given index from the table.
      #
      # @param table_name [String, Symbol]
      # @param options [Hash] optional
      def remove_index(table_name, column_name = nil, **options)
        if ActiveRecord::VERSION::STRING >= '6.1'
          return if options[:if_exists] && !index_exists?(table_name, column_name, **options)
          index_name = index_name_for_remove(table_name, column_name, options)
        else
          index_name = index_name_for_remove(table_name, options)
        end

        execute "ALTER TABLE #{quote_table_name(table_name)} DROP INDEX #{quote_column_name(index_name)}"
      end

      def schema_creation
        SchemaCreation.new(self)
      end

      def change_table(table_name, _options = {})
        recorder = ActiveRecord::Migration::CommandRecorder.new(self)
        yield update_table_definition(table_name, recorder)
        bulk_change_table(table_name, recorder.commands)
      end

      # Returns the MySQL error number from the exception. The
      # AbstractMysqlAdapter requires it to be implemented
      def error_number(_exception); end

      def full_version
        if ActiveRecord::VERSION::MAJOR < 6
          get_full_version
        elsif ActiveRecord::VERSION::MAJOR >= 7 && ActiveRecord::VERSION::MINOR >= 2
          database_version.full_version_string
        else
          schema_cache.database_version.full_version_string
        end
      end

      # This is a method defined in Rails 6.0, and we have no control over the
      # naming of this method.
      def get_full_version # rubocop:disable Style/AccessorMethodName
        mysql_adapter.raw_connection.server_info[:version]
      end

      def last_inserted_id(result)
        mysql_adapter.send(:last_inserted_id, result)
      end

      private

      attr_reader :mysql_adapter

      if ActiveRecord::VERSION::MAJOR >= 7 && ActiveRecord::VERSION::MINOR >= 1
        def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: true)
          log(sql, name, async: async) do |notification_payload|
            with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
              sync_timezone_changes(conn)
              result = conn.query(sql)
              conn.abandon_results! if ActiveRecord::VERSION::MINOR >= 2
              verified! if ActiveRecord.version >= Gem::Version.create('7.1.2')
              handle_warnings(sql)
              notification_payload[:row_count] = result&.size || 0 if ActiveRecord::VERSION::MINOR >= 2
              result
            end
          end
        end

        if ActiveRecord::VERSION::MINOR >= 2
          def connect
            @raw_connection = self.class.new_client(@connection_parameters)
          rescue ConnectionNotEstablished => ex
            raise ex.set_pool(@pool)
          end

          def reconnect
            @raw_connection&.close
            @raw_connection = nil
            connect
          end
        else
          def reconnect; end
        end
      end
    end
  end
end
