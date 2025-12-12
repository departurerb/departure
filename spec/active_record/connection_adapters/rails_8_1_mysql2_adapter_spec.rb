require 'spec_helper'

if rails_version_under_test_matches?(RAILS_8_1, __FILE__)
  require 'active_record/connection_adapters/rails_8_1_mysql2_adapter'

  describe ActiveRecord::ConnectionAdapters::Rails81Mysql2Adapter, activerecord_compatibility: RAILS_8_1 do
    let(:adapter) { described_class.new(db_config_for(adapter: 'mysql2')) }
    let(:client) { described_class.new_client(db_config_for(adapter: 'mysql2')) }

    describe '#new_client' do
      it 'wraps the underlying db_client and exposes a mysql_client' do
        expect(client).to be_a(Departure::DbClient)
        expect(client.database_client).to be_a(Mysql2::Client)
      end
    end

    describe 'database_statements' do
      let(:table_name) { :foo }
      let(:column_name) { :bar_id }
      let(:index_name) { 'index_name' }
      let(:options) { { type: 'index_type' } }

      describe '#add_index' do
        let(:index_definition) do
          ActiveRecord::ConnectionAdapters::IndexDefinition.new(
            table_name,
            index_name,
            nil,
            [column_name],
            **options
          )
        end

        let(:index_options) { [index_definition, nil, false] }
        let(:index_type) { options[:type].upcase }
        let(:schema_creation_double) { instance_double(described_class::SchemaCreation) }

        it 'passes the built ALTER TABLE SQL to #execute' do
          allow(adapter).to receive(:shard) { :default }
          allow(adapter).to receive(:role) { :writing }

          expect(schema_creation_double).to receive(:accept).with(index_definition) {
            "INDEX_TYPE INDEX `#{index_name}` (`#{column_name}`)"
          }
          expect(adapter).to receive(:schema_creation) { schema_creation_double }

          expect(adapter).to receive(:add_index_options).with(table_name, column_name,
                                                              options).and_return(index_options)
          execute_sql = "ALTER TABLE `#{table_name}` ADD #{index_type} INDEX `#{index_name}` (`#{column_name}`)"
          expect(adapter).to receive(:execute).with(execute_sql).and_return(true)

          adapter.add_index(table_name, column_name, options)
        end
      end

      describe '#remove_index' do
        let(:options) { { column: column_name } }
        let(:sql) { "DROP INDEX `#{index_name}`" }

        it 'passes the built ALTER TABLE SQL to #execute' do
          allow(adapter).to receive(:shard) { :default }
          allow(adapter).to receive(:role) { :writing }
          expect(adapter).to receive(:index_name_for_remove).with(table_name, nil, options).and_return(index_name.to_s)
          execute_sql = "ALTER TABLE `#{table_name}` DROP INDEX `#{index_name}`"
          expect(adapter).to receive(:execute).with(execute_sql).and_return(true)

          adapter.remove_index(table_name, **options)
        end
      end
    end
  end
end
