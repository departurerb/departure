require 'active_record/connection_adapters/abstract_mysql_adapter'
require 'active_record/connection_adapters/mysql2_adapter'
require 'active_record/connection_adapters/patch_connection_handling'
require 'departure'
require 'forwardable'

module ActiveRecord
  module ConnectionAdapters
    class Rails81DepartureAdapter < ActiveRecord::ConnectionAdapters::Mysql2Adapter
      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) } if defined?(initialize_type_map)

      class Column < ActiveRecord::ConnectionAdapters::MySQL::Column
        def adapter
          Rails81DepartureAdapter
        end
      end

      # https://github.com/departurerb/departure/commit/f178ca26cd3befa1c68301d3b57810f8cdcff9eb
      # For `DROP FOREIGN KEY constraint_name` with pt-online-schema-change requires specifying `_constraint_name`
      # rather than the real constraint_name due to to a limitation in MySQL
      # pt-online-schema-change adds a leading underscore to foreign key constraint names when creating the new table.
      # https://www.percona.com/blog/2017/03/21/dropping-foreign-key-constraint-using-pt-online-schema-change-2/
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

      # add_index is modified from the underlying mysql adapter implementation to ensure we add ALTER TABLE to it
      def add_index(table_name, column_name, options = {})
        index_definition, = add_index_options(table_name, column_name, **options)
        execute <<-SQL.squish
          ALTER TABLE #{quote_table_name(index_definition.table)}
            ADD #{schema_creation.accept(index_definition)}
        SQL
      end

      # remove_index is modified from the underlying mysql adapter implementation to ensure we add ALTER TABLE to it
      def remove_index(table_name, column_name = nil, **options)
        return if options[:if_exists] && !index_exists?(table_name, column_name, **options)

        index_name = index_name_for_remove(table_name, column_name, options)

        execute "ALTER TABLE #{quote_table_name(table_name)} DROP INDEX #{quote_column_name(index_name)}"
      end

      def schema_creation
        SchemaCreation.new(self)
      end

      private

      attr_reader :mysql_adapter

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/ParameterLists
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
          rescue ::Mysql2::Error => e
            @statements.delete(sql)
            # Sometimes for an unknown reason, we get that error.
            # It suggest somehow that the prepared statement was deallocated
            # but the client doesn't know it.
            # But we know that this error is safe to retry, so we do so after
            # getting rid of the originally cached statement.
            if e.error_number == Mysql2Adapter::ER_UNKNOWN_STMT_HANDLER && retry_count.positive?
              retry_count -= 1
              retry
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
    end
  end
end
