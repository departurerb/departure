require 'active_record/connection_adapters/abstract_mysql_adapter'
require 'active_record/connection_adapters/mysql2_adapter'
require 'active_record/connection_adapters/patch_connection_handling'
require 'departure'
require 'forwardable'

module ActiveRecord
  module ConnectionAdapters
    class Rails81Mysql2Adapter < ActiveRecord::ConnectionAdapters::Mysql2Adapter
      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) } if defined?(initialize_type_map)

      class Column < ActiveRecord::ConnectionAdapters::MySQL::Column
        def adapter
          Rails81Mysql2Adapter
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

      include ForAlterStatements unless method_defined?(:change_column_for_alter)

      ADAPTER_NAME = 'Percona'.freeze

      def self.new_client(config)
        original_client = super

        Departure::DbClient.new(config, original_client)
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

      # rubocop:disable Metrics/ParameterLists
      def perform_query(raw_connection, sql, binds, type_casted_binds, prepare:, notification_payload:, batch: false)
        return raw_connection.send_to_pt_online_schema_change(sql) if raw_connection.alter_statement?(sql)

        super
      end
      # rubocop:enable Metrics/ParameterLists
    end
  end
end
