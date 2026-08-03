require "active_record/connection_adapters/abstract_mysql_adapter"
require "active_record/connection_adapters/trilogy_adapter"
require "active_record/connection_adapters/patch_connection_handling"
require "departure"
require "active_record/connection_adapters/departure_adapter_behavior"

module ActiveRecord
  module ConnectionAdapters
    class Rails72TrilogyAdapter < ActiveRecord::ConnectionAdapters::TrilogyAdapter
      class Column < ActiveRecord::ConnectionAdapters::MySQL::Column
        def adapter
          Rails72TrilogyAdapter
        end
      end

      ADAPTER_NAME = "Percona".freeze

      include DepartureAdapterBehavior::SchemaStatements
      extend DepartureAdapterBehavior::DbClientConnection

      def new_column(...)
        Column.new(...)
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
