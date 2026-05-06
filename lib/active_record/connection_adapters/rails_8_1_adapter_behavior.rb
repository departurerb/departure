module ActiveRecord
  module ConnectionAdapters
    module Rails81AdapterBehavior
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

      def self.included(adapter_class)
        adapter_class.const_set(:SchemaCreation, SchemaCreation)
        adapter_class.extend(ClassMethods)
        adapter_class.include ForAlterStatements unless adapter_class.method_defined?(:change_column_for_alter)
      end

      module ClassMethods
        def new_client(config)
          original_client = super

          Departure::DbClient.new(config, original_client)
        end
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
        self.class::SchemaCreation.new(self)
      end

      private

      # rubocop:disable Metrics/ParameterLists
      def perform_query(raw_connection, sql, binds, type_casted_binds, prepare:, notification_payload:, batch: false)
        return raw_connection.send_to_pt_online_schema_change(sql) if raw_connection.alter_statement?(sql)

        super
      end
      # rubocop:enable Metrics/ParameterLists
    end
  end
end
