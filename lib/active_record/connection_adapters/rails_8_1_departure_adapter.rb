require 'active_record/connection_adapters/abstract_mysql_adapter'
require 'active_record/connection_adapters/mysql2_adapter'
require 'active_record/connection_adapters/patch_connection_handling'
require 'departure'
require 'forwardable'

module ActiveRecord
  module ConnectionAdapters
    class Rails81DepartureAdapter < ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter
      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) } if defined?(initialize_type_map)

      class Column < ActiveRecord::ConnectionAdapters::MySQL::Column
        def adapter
          Rails81DepartureAdapter
        end
      end

      class SchemaCreation < ActiveRecord::ConnectionAdapters::MySQL::SchemaCreation
        def visit_DropForeignKey(name) # rubocop:disable Naming/MethodName
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

      include ForAlterStatements unless method_defined?(:change_column_for_alter)

      ADAPTER_NAME = 'Percona'.freeze

      def self.new_client(config)
        connection_details = Departure::ConnectionDetails.new(config)
        verbose = ActiveRecord::Migration.verbose
        sanitizers = [
          Departure::LogSanitizers::PasswordSanitizer.new(connection_details)
        ]
        percona_logger = Departure::LoggerFactory.build(sanitizers: sanitizers, verbose: verbose)
        cli_generator = Departure::CliGenerator.new(connection_details)

        mysql_adapter = ActiveRecord::ConnectionAdapters::Mysql2Adapter.new(config.merge(adapter: 'mysql2'))

        Departure::Runner.new(
          percona_logger,
          cli_generator,
          mysql_adapter
        )
      end

      def initialize(config)
        super

        @config[:flags] ||= 0

        if @config[:flags].is_a? Array
          @config[:flags].push 'FOUND_ROWS'
        else
          @config[:flags] |= ::Mysql2::Client::FOUND_ROWS
        end

        @prepared_statements = false
      end

      def write_query?(sql) # :nodoc:
        !ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
          :desc, :describe, :set, :show, :use
        ).match?(sql)
      end

      def exec_delete(sql, name, binds)
        execute(to_sql(sql, binds), name)

        @raw_connection.affected_rows
      end
      alias exec_update exec_delete

      def exec_insert(sql, name, binds, pky = nil, sequence_name = nil, returning: nil) # rubocop:disable Lint/UnusedMethodArgument, Metrics/ParameterLists
        execute(to_sql(sql, binds), name)
      end

      def internal_exec_query(sql, name = 'SQL', _binds = [], **_kwargs) # :nodoc:
        result = execute(sql, name)
        fields = result.fields if defined?(result.fields)
        ActiveRecord::Result.new(fields || [], result.to_a)
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

      def new_column(...)
        Column.new(...)
      end

      # Adds a new index to the table
      #
      # @param table_name [String, Symbol]
      # @param column_name [String, Symbol]
      # @param options [Hash] optional
      def add_index(table_name, column_name, options = {})
        index_definition, = add_index_options(table_name, column_name, **options)
        execute <<-SQL.squish
          ALTER TABLE #{quote_table_name(index_definition.table)}
            ADD #{schema_creation.accept(index_definition)}
        SQL
      end

      # Remove the given index from the table.
      #
      # @param table_name [String, Symbol]
      # @param options [Hash] optional
      def remove_index(table_name, column_name = nil, **options)
        return if options[:if_exists] && !index_exists?(table_name, column_name, **options)

        index_name = index_name_for_remove(table_name, column_name, options)

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

      def full_version
        get_full_version
      end

      def get_full_version # rubocop:disable Naming/AccessorMethodName
        return @get_full_version if defined? @get_full_version

        with_raw_connection do |conn|
          @get_full_version = conn.database_adapter.get_database_version.full_version_string
        end
      end

      def last_inserted_id(result)
        @raw_connection.database_adapter.send(:last_inserted_id, result)
      end

      private

      attr_reader :mysql_adapter

      # def each_hash(result, &block) # :nodoc:
      #   @raw_connection.database_adapter.each_hash(result, &block)
      # end

      # Must return the MySQL error number from the exception, if the exception has an
      # error number.
      # def error_number(exception)
      #   @raw_connection.database_adapter.error_number(exception)
      # end

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/ParameterLists
      # def raw_execute(sql, name = nil, binds = [], prepare: false, async: false, allow_retry: false, materialize_transactions: true, batch: false)
      #   type_casted_binds = type_casted_binds(binds)
      #   log(sql, name, binds, type_casted_binds, async: async, allow_retry) do |notification_payload|
      #     with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
      #       perform_query(conn, sql, binds, type_casted_binds, prepare: prepare,
      #                                                          notification_payload: notification_payload, batch: batch)
      #     end
      #   end
      # end

      def perform_query(raw_connection, sql, binds, type_casted_binds, prepare:, notification_payload:, batch: false)
        reset_multi_statement = if batch && !multi_statements_enabled?
                                  raw_connection.set_server_option(::Mysql2::Client::OPTION_MULTI_STATEMENTS_ON)
                                  true
                                end

        # Make sure we carry over any changes to ActiveRecord.default_timezone that have been
        # made since we established the connection
        raw_connection.query_options[:database_timezone] = default_timezone

        result = nil
        if binds.nil? || binds.empty?
          result = raw_connection.query(sql)
          # Ref: https://github.com/brianmario/mysql2/pull/1383
          # As of mysql2 0.5.6 `#affected_rows` might raise Mysql2::Error if a prepared statement
          # from that same connection was GCed while `#query` released the GVL.
          # By avoiding to call `#affected_rows` when we have a result, we reduce the likeliness
          # of hitting the bug.

          # THIS IS THE CORE CHANGES 2 related to size - it will not be present on pt-online-schema-migrator calls
          @affected_rows_before_warnings = result.try(:size) || raw_connection.affected_rows
        elsif prepare
          retry_count = 1
          begin
            stmt = @statements[sql] ||= raw_connection.prepare(sql)
            result = stmt.execute(*type_casted_binds)
            @affected_rows_before_warnings = stmt.affected_rows
          rescue ::Mysql2::Error => error
            @statements.delete(sql)
            # Sometimes for an unknown reason, we get that error.
            # It suggest somehow that the prepared statement was deallocated
            # but the client doesn't know it.
            # But we know that this error is safe to retry, so we do so after
            # getting rid of the originally cached statement.
            if error.error_number == Mysql2Adapter::ER_UNKNOWN_STMT_HANDLER
              if retry_count.positive?
                retry_count -= 1
                retry
              end
            end
            raise
          end
        else
          stmt = raw_connection.prepare(sql)

          begin
            result = stmt.execute(*type_casted_binds)
            @affected_rows_before_warnings = stmt.affected_rows

            # Ref: https://github.com/brianmario/mysql2/pull/1383
            # by eagerly closing uncached prepared statements, we also reduce the chances of
            # that bug happening. It can still happen if `#execute` is used as we have no callback
            # to eagerly close the statement.
            if result
              result.instance_variable_set(:@_ar_stmt_to_close, stmt)
            else
              stmt.close
            end
          rescue ::Mysql2::Error
            stmt.close
            raise
          end
        end

        notification_payload[:affected_rows] = @affected_rows_before_warnings

        # THIS IS THE CORE CHANGES 2 related to size - it will not be present on pt-online-schema-migrator calls
        notification_payload[:row_count] = result.try(:size) || 0

        if result.is_a? Process::Status
          notification_payload[:exit_code] = result.exitstatus
          notification_payload[:exit_pid] = result.pid
        end

        raw_connection.abandon_results!

        verified!
        result
      ensure
        if reset_multi_statement && active?
          raw_connection.set_server_option(::Mysql2::Client::OPTION_MULTI_STATEMENTS_OFF)
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/ParameterLists

      def connect
        @raw_connection = self.class.new_client(@config)
      rescue ConnectionNotEstablished => e
        raise e.set_pool(@pool)
      end

      def reconnect
        @lock.synchronize do
          @raw_connection&.close
          @raw_connection = nil
          connect
        end
      end
    end
  end
end
