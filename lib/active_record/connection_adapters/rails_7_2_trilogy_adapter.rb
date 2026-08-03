require "active_record/connection_adapters/abstract_mysql_adapter"
require "active_record/connection_adapters/trilogy_adapter"
require "active_record/connection_adapters/patch_connection_handling"
require "departure"

module ActiveRecord
  module ConnectionAdapters
    class Rails72TrilogyAdapter < ActiveRecord::ConnectionAdapters::TrilogyAdapter
      class Column < ActiveRecord::ConnectionAdapters::MySQL::Column
        def adapter
          Rails72TrilogyAdapter
        end
      end

      class SchemaCreation < ActiveRecord::ConnectionAdapters::MySQL::SchemaCreation
        def visit_DropForeignKey(name) # standard:disable Naming/MethodName
          fk_name =
            if name =~ /^__(.+)/
              Regexp.last_match(1)
            else
              "_#{name}"
            end

          "DROP FOREIGN KEY #{fk_name}"
        end
      end

      ADAPTER_NAME = "Percona".freeze

      include ForAlterStatements unless method_defined?(:change_column_for_alter)

      def self.new_client(config)
        original_client = super

        Departure::DbClient.new(config, original_client)
      end

      def new_column(...)
        Column.new(...)
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

      # Rails 7.2 has no perform_query hook, so the interception happens here:
      # the DbClient wrapper routes ALTER TABLE statements to
      # pt-online-schema-change, which yields a Process::Status instead of a
      # Trilogy::Result.
      def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: true)
        log(sql, name, async: async) do |notification_payload|
          with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
            sync_timezone_changes(conn)
            result = conn.query(sql)
            while conn.more_results_exist?
              conn.next_result
            end
            verified!
            handle_warnings(sql)
            if result.is_a?(Process::Status)
              notification_payload[:exit_code] = result.exitstatus
              notification_payload[:exit_pid] = result.pid
            elsif result.respond_to?(:count)
              notification_payload[:row_count] = result.count
            end
            result
          end
        end
      end
    end
  end
end
