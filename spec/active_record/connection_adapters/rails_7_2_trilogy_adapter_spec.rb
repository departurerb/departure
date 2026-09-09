require "spec_helper"

describe "ActiveRecord::ConnectionAdapters::Rails72TrilogyAdapter", activerecord_compatibility: RAILS_7_2 do
  let(:described_class) do
    # has to be required here because trilogy is only installed for the
    # appraisals that support it
    require "active_record/connection_adapters/rails_7_2_trilogy_adapter"

    ActiveRecord::ConnectionAdapters::Rails72TrilogyAdapter
  end

  let(:adapter) { described_class.new(db_config_for(adapter: "trilogy")) }
  let(:client) { described_class.new_client(db_config_for(adapter: "trilogy")) }
  let(:trilogy_double) { instance_double(::Trilogy) }

  describe "#new_client" do
    it "wraps the underlying db_client and exposes a mysql_client" do
      expect(::Trilogy).to receive(:new) { trilogy_double }

      expect(client).to be_a(Departure::DbClient)
      expect(client.database_client).to be(trilogy_double)
    end
  end

  describe "#execute" do
    let(:db_client) { double(:db_client, more_results_exist?: false, query_flags: 0) }

    before do
      allow(adapter).to receive(:with_raw_connection).and_yield(db_client)
      allow(db_client).to receive(:query_flags=)
    end

    it "sends the SQL through the db client, which routes ALTER statements" do
      sql = "ALTER TABLE `comments` ADD `foo` INT"
      system("true", out: File::NULL)
      process_status = $?

      expect(db_client).to receive(:query).with(sql) { process_status }

      expect(adapter.execute(sql)).to eq(process_status)
    end
  end

  describe "database_statements" do
    let(:table_name) { :foo }
    let(:column_name) { :bar_id }
    let(:index_name) { "index_name" }
    let(:options) { {type: "index_type"} }

    describe "#add_index" do
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

      it "passes the built ALTER TABLE SQL to #execute" do
        allow(adapter).to receive(:shard) { :default }
        allow(adapter).to receive(:role) { :writing }

        expect(schema_creation_double).to receive(:accept).with(index_definition) {
          "INDEX_TYPE INDEX `#{index_name}` (`#{column_name}`)"
        }
        expect(adapter).to receive(:schema_creation) { schema_creation_double }

        expect(adapter).to receive(:add_index_options).with(table_name, column_name, options).and_return(index_options)
        execute_sql = "ALTER TABLE `#{table_name}` ADD #{index_type} INDEX `#{index_name}` (`#{column_name}`)"
        expect(adapter).to receive(:execute).with(execute_sql).and_return(true)

        adapter.add_index(table_name, column_name, options)
      end
    end

    describe "#remove_index" do
      let(:options) { {column: column_name} }

      it "passes the built ALTER TABLE SQL to #execute" do
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
