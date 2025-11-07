require 'spec_helper'
require 'active_record/connection_adapters/rails_8_0_departure_adapter'

describe ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter, activerecord_compatibility: RAILS_8_0 do
  describe ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter::Column do
    let(:field) { double(:field) }
    let(:default) { double(:default) }
    let(:cast_type) do
      if defined?(ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::MysqlString)
        ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::MysqlString.new
      else
        ActiveRecord::Type.lookup(:string, adapter: :mysql2)
      end
    end
    let(:metadata) do
      ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(
        type: cast_type.type,
        sql_type: type,
        limit: cast_type.limit
      )
    end
    let(:mysql_metadata) do
      ActiveRecord::ConnectionAdapters::MySQL::TypeMetadata.new(metadata)
    end
    let(:type) { 'VARCHAR' }
    let(:null) { double(:null) }
    let(:collation) { double(:collation) }

    let(:column) do
      described_class.new('field', 'default', mysql_metadata, null, collation: 'collation')
    end

    describe '#adapter' do
      subject { column.adapter }
      it do
        is_expected.to eq(
          ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter
        )
      end
    end
  end

  let(:config) do
    {
      prepared_statements: '',
      username: 'root',
      password: 'password',
      database: 'some_test_db'
    }
  end

  let(:internal_added_config) do
    {
      adapter: 'mysql2',
      flags: anything
    }
  end

  let(:database_version) { double(full_version_string: '8.0.01') }
  let(:mysql_adapter) do
    instance_double(ActiveRecord::ConnectionAdapters::Mysql2Adapter, get_database_version: database_version)
  end
  let(:logger) { double(:logger, puts: true) }
  let(:query_options) { { database_timezone: :utc } }
  let(:runner) do
    instance_double(Departure::Runner).tap do |r|
      allow(r).to receive(:database_adapter).and_return(mysql_adapter)
      allow(r).to receive(:query_options).and_return(query_options)
      allow(r).to receive(:close).and_return(true)
      allow(r).to receive(:abandon_results!).and_return(true)
      allow(r).to receive(:affected_rows).and_return(1)
      allow(r).to receive(:query).and_return(nil)
      allow(r).to receive(:execute).with('percona command').and_return(true)
    end
  end
  let(:cli_generator) { instance_double(Departure::CliGenerator, generate: 'percona command') }
  let(:adapter) { described_class.new(config).tap { |adapter| adapter.send(:connect) } }
  let(:mysql_client) { double(:mysql_client) }

  before do
    allow(mysql_client).to receive(:server_info).and_return(version: '8.0.19')
    allow(mysql_adapter).to receive(:raw_connection).and_return(mysql_client)
    allow(Departure::LoggerFactory).to receive(:build) { logger }

    # Add a default stub for Mysql2Adapter.new to handle any config
    allow(ActiveRecord::ConnectionAdapters::Mysql2Adapter).to receive(:new).and_return(mysql_adapter)

    allow(Departure::CliGenerator).to(
      receive(:new).and_return(cli_generator)
    )
    allow(Departure::Runner).to(
      receive(:new).with(logger, cli_generator, mysql_adapter)
    ).and_return(runner)
  end

  it '#supports_migrations?' do
    expect(adapter.supports_migrations?).to eql(true)
  end

  describe '#new_column' do
    let(:field) { double(:field) }
    let(:default) { double(:default) }
    let(:type) { double(:type) }
    let(:null) { double(:null) }
    let(:collation) { double(:collation) }
    let(:table_name) { double(:table_name) }
    let(:default_function) { double(:default_function) }
    let(:comment) { double(:comment) }

    it do
      expect(ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter::Column).to receive(:new)
      adapter.new_column(field, default, type, null, table_name, default_function, collation, comment)
    end
  end

  describe 'schema statements' do
    describe '#add_index' do
      let(:table_name) { :foo }
      let(:column_name) { :bar_id }
      let(:index_name) { 'index_name' }
      let(:options) { { type: 'index_type' } }
      let(:index_type) { options[:type].upcase }
      let(:sql) { 'ADD index_type INDEX `index_name` (bar_id)' }
      let(:index_options) do
        [
          ActiveRecord::ConnectionAdapters::IndexDefinition.new(
            table_name,
            index_name,
            nil,
            [column_name],
            **options
          ),
          nil,
          false
        ]
      end

      let(:expected_sql) do
        "ALTER TABLE `#{table_name}` ADD #{index_type} INDEX `#{index_name}` (`#{column_name}`)"
      end

      before do
        allow(adapter).to(
          receive(:add_index_options)
          .with(table_name, column_name, options)
          .and_return(index_options)
        )
      end

      it 'passes the built SQL to #execute' do
        allow(runner).to receive(:query).with(anything)
        expect(runner).to receive(:close)
        expect(adapter).to receive(:execute).with(expected_sql)
        adapter.add_index(table_name, column_name, options)
      end
    end

    describe '#remove_index' do
      let(:table_name) { :foo }
      let(:options) { { column: :bar_id } }
      let(:sql) { 'DROP INDEX `index_name`' }

      before do
        allow(adapter).to(
          receive(:index_name_for_remove)
          .with(table_name, options)
          .and_return('index_name')
        )
        allow(adapter).to(
          receive(:index_name_for_remove)
          .with(table_name, nil, options)
          .and_return('index_name')
        )
      end

      it 'passes the built SQL to #execute' do
        expect(adapter).to(
          receive(:execute)
          .with("ALTER TABLE `#{table_name}` DROP INDEX `index_name`")
        )
        adapter.remove_index(table_name, **options)
      end
    end
  end

  describe '#exec_delete' do
    let(:sql) { 'DELETE FROM comments WHERE id = 1' }
    let(:affected_rows) { 1 }
    let(:name) { nil }
    let(:binds) { nil }

    before do
      allow(runner).to receive(:query).with(anything)
      allow(mysql_client).to receive(:affected_rows).and_return(affected_rows)
    end

    it 'executes the sql' do
      expect(runner).to receive(:affected_rows)
      expect(adapter).to(receive(:execute).with(sql, name))
      adapter.exec_delete(sql, name, binds)
    end

    it 'returns the number of affected rows' do
      expect(runner).to receive(:close)
      expect(runner).to receive(:affected_rows) { affected_rows }
      expect(adapter.exec_delete(sql, name, binds)).to eq(affected_rows)
    end
  end

  describe '#exec_insert' do
    let(:sql) { 'INSERT INTO comments (id) VALUES (20)' }
    let(:name) { nil }
    let(:binds) { nil }

    it 'executes the sql' do
      expect(adapter).to(receive(:execute).with(sql, name))
      adapter.exec_insert(sql, name, binds)
    end
  end

  describe '#exec_query' do
    let(:sql) { 'SELECT * FROM comments' }
    let(:name) { nil }
    let(:binds) { nil }

    before do
      allow(runner).to receive(:query).with(sql)
      allow(adapter).to(
        receive(:execute).with(sql, name).and_return(result_set)
      )
    end

    context 'when the adapter returns results' do
      let(:result_set) { double(fields: ['id'], to_a: [1]) }

      it 'executes the sql' do
        expect(adapter).to(
          receive(:execute).with(sql, name)
        ).and_return(result_set)

        adapter.exec_query(sql, name, binds)
      end

      it 'returns an ActiveRecord::Result' do
        expect(ActiveRecord::Result).to(
          receive(:new).with(result_set.fields, result_set.to_a)
        )
        adapter.exec_query(sql, name, binds)
      end
    end

    context 'when the adapter returns nil' do
      let(:result_set) { nil }

      it 'executes the sql' do
        expect(adapter).to(
          receive(:execute).with(sql, name)
        ).and_return(result_set)

        adapter.exec_query(sql, name, binds)
      end

      it 'returns an ActiveRecord::Result' do
        expect(ActiveRecord::Result).to(
          receive(:new).with([], [])
        )
        adapter.exec_query(sql, name, binds)
      end
    end
  end

  describe '#last_inserted_id' do
    let(:result) { double(:result) }

    it 'delegates to the mysql adapter' do
      expect(mysql_adapter).to(
        receive(:last_inserted_id).with(result)
      )
      adapter.last_inserted_id(result)
    end
  end

  describe '#select_rows' do
    subject { adapter.select_rows(sql, name) }

    let(:sql) { 'SELECT id, body FROM comments' }
    let(:name) { nil }

    let(:array_of_rows) { [%w[1 body], %w[2 body]] }
    let(:mysql2_result) do
      # rubocop:disable Style/WordArray
      instance_double(Mysql2::Result, to_a: array_of_rows, fields: ['id', 'body'])
      # rubocop:enable Style/WordArray
    end

    before do
      allow(adapter).to(
        receive(:execute).with(sql, name)
      ).and_return(mysql2_result)
    end

    it { is_expected.to match_array(array_of_rows) }
  end

  describe '#select' do
    subject { adapter.select(sql, name) }

    let(:sql) { 'SELECT id, body FROM comments' }
    let(:name) { nil }

    let(:array_of_rows) { [%w[1 body], %w[2 body]] }
    let(:mysql2_result) do
      instance_double(Mysql2::Result, fields: %w[id body], to_a: array_of_rows)
    end

    before do
      allow(adapter).to(
        receive(:execute).with(sql, name)
      ).and_return(mysql2_result)
    end

    it do
      is_expected.to match_array(
        [
          { 'id' => '1', 'body' => 'body' },
          { 'id' => '2', 'body' => 'body' }
        ]
      )
    end
  end

  describe '#write_query?' do
    it 'identifies write queries correctly' do
      expect(adapter.write_query?('INSERT INTO comments (id) VALUES (1)')).to be true
      expect(adapter.write_query?('UPDATE comments SET body = "test"')).to be true
      expect(adapter.write_query?('DELETE FROM comments WHERE id = 1')).to be true
      expect(adapter.write_query?('ALTER TABLE comments ADD COLUMN test VARCHAR(255)')).to be true
    end

    it 'identifies read queries correctly' do
      expect(adapter.write_query?('SELECT * FROM comments')).to be false
      expect(adapter.write_query?('SHOW TABLES')).to be false
      expect(adapter.write_query?('DESCRIBE comments')).to be false
      expect(adapter.write_query?('DESC comments')).to be false
    end
  end

  describe '#full_version' do
    it 'returns the database version' do
      expect(adapter.full_version).to eq('8.0.01')
    end
  end

  describe '#get_full_version' do
    it 'caches the version after first call' do
      version = adapter.get_full_version
      expect(version).to eq('8.0.01')

      # Call again to test caching
      expect(mysql_adapter).not_to receive(:get_database_version)
      second_version = adapter.get_full_version
      expect(second_version).to eq('8.0.01')
    end
  end

  describe '#schema_creation' do
    it 'returns a SchemaCreation instance' do
      expect(adapter.schema_creation).to be_a(
        ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter::SchemaCreation
      )
    end
  end

  describe ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter::SchemaCreation do
    let(:adapter) { instance_double(ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter) }
    let(:schema_creation) { described_class.new(adapter) }

    describe '#visit_DropForeignKey' do
      context 'when the foreign key name has double underscore prefix' do
        it 'removes the double underscore prefix' do
          result = schema_creation.visit_DropForeignKey('__fk_constraint_name')
          expect(result).to eq('DROP FOREIGN KEY fk_constraint_name')
        end
      end

      context 'when the foreign key name does not have double underscore prefix' do
        it 'adds a single underscore prefix' do
          result = schema_creation.visit_DropForeignKey('fk_constraint_name')
          expect(result).to eq('DROP FOREIGN KEY _fk_constraint_name')
        end
      end
    end
  end

  describe '.new_client' do
    before do
      # For .new_client tests, we need to stub Mysql2Adapter without the flags requirement
      # since new_client doesn't go through the initialization that adds flags
      allow(ActiveRecord::ConnectionAdapters::Mysql2Adapter).to receive(:new)
        .with(hash_including(adapter: 'mysql2')).and_return(mysql_adapter)

      # Stub ConnectionDetails which is used by new_client
      allow(Departure::ConnectionDetails).to receive(:new).with(config).and_return(
        double('ConnectionDetails',
               password: 'password',
               username: 'root',
               hostname: 'localhost',
               database: 'some_test_db',
               port: 3306)
      )
    end

    it 'creates a new Departure::Runner instance' do
      # Allow real Runner creation for this test
      allow(Departure::Runner).to receive(:new).and_call_original

      client = described_class.new_client(config)
      expect(client).to be_a(Departure::Runner)
    end

    it 'configures the runner with proper dependencies' do
      expect(Departure::LoggerFactory).to receive(:build).and_return(logger)
      expect(Departure::CliGenerator).to receive(:new).and_return(cli_generator)
      expect(Departure::Runner).to receive(:new).with(logger, cli_generator, anything)

      described_class.new_client(config)
    end
  end

  describe '#change_table' do
    let(:table_name) { :test_table }
    let(:recorder) { instance_double(ActiveRecord::Migration::CommandRecorder, commands: []) }

    before do
      allow(ActiveRecord::Migration::CommandRecorder).to receive(:new).and_return(recorder)
      allow(adapter).to receive(:update_table_definition).and_return(double)
      allow(adapter).to receive(:bulk_change_table)
    end

    it 'uses a CommandRecorder to track changes' do
      expect(ActiveRecord::Migration::CommandRecorder).to receive(:new).with(adapter)
      adapter.change_table(table_name) { |_t| }
    end

    it 'calls bulk_change_table with the recorded commands' do
      expect(adapter).to receive(:bulk_change_table).with(table_name, [])
      adapter.change_table(table_name) { |_t| }
    end
  end

  describe 'initialization' do
    it 'sets prepared_statements to false' do
      new_adapter = described_class.new(config)
      expect(new_adapter.instance_variable_get(:@prepared_statements)).to be false
    end

    it 'configures flags for FOUND_ROWS when flags is a number' do
      config_with_flags = config.merge(flags: 0)
      new_adapter = described_class.new(config_with_flags)
      expect(new_adapter.instance_variable_get(:@config)[:flags]).to eq(Mysql2::Client::FOUND_ROWS)
    end

    it 'adds FOUND_ROWS to flags array when flags is an array' do
      config_with_flags = config.merge(flags: [])
      new_adapter = described_class.new(config_with_flags)
      expect(new_adapter.instance_variable_get(:@config)[:flags]).to include('FOUND_ROWS')
    end
  end
end
