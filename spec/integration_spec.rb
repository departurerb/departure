require 'spec_helper'
require_relative './dummy/db/migrate/0022_add_timestamp_on_comments'

# TODO: Handle #change_table syntax
describe Departure, integration: true do
  class Comment < ActiveRecord::Base; end

  let(:direction) { :up }
  let(:pool) { ActiveRecord::Base.connection_pool }
  let(:spec_config) do
    ar_version = ActiveRecord::VERSION::STRING

    if Departure::RailsAdapter.version_matches?(ar_version, '~> 8.0')
      pool.connections.first.instance_variable_get(:@config)
    elsif Departure::RailsAdapter.version_matches?(ar_version, '>= 6.1')
      pool.connection.instance_variable_get(:@config)
    else
      pool.spec.config
    end
  end

  it 'has a version number' do
    expect(Departure::VERSION).not_to be nil
  end

  describe 'logging' do
    context 'when the migration logging is disabled' do
      around(:each) do |example|
        original_verbose = ActiveRecord::Migration.verbose
        ActiveRecord::Migration.verbose = false
        example.run
        ActiveRecord::Migration.verbose = original_verbose
      end

      it "doesn't send the output to stdout" do
        expect do
          run_a_migration(direction, 1)
        end.to_not output.to_stdout
      end
    end

    context 'when the migration logging is enabled' do
      around(:each) do |example|
        original_verbose = ActiveRecord::Migration.verbose
        ActiveRecord::Migration.verbose = true
        example.run
        ActiveRecord::Migration.verbose = original_verbose
      end

      it 'sends the output to stdout' do
        expect do
          run_a_migration(direction, 1)
        end.to output.to_stdout
      end
    end
  end

  context 'when ActiveRecord is loaded' do
    let(:db_config) { Configuration.new }

    it 'reconnects to the database using PerconaAdapter' do
      run_a_migration(direction, 1)
      expect(spec_config[:adapter]).to eq('percona')
    end

    context 'when a username is provided' do
      before do
        establish_percona_connection(username: db_config['username'])
      end

      it 'uses the provided username' do
        run_a_migration(direction, 1)
        expect(spec_config[:username]).to eq('root')
      end
    end

    # TODO: Use dummy app so that we actually go through the railtie's code
    context 'when there is LHM' do
      xit 'patches it to use regular Rails migration methods' do
        expect(Departure::Lhm::Fake::Adapter)
          .to receive(:new).and_return(true)
        run_a_migration(direction, 1)
      end
    end

    context 'when there is no LHM' do
      xit 'does not patch it' do
        expect(Departure::Lhm::Fake).not_to receive(:patching_lhm)
        run_a_migration(direction, 1)
      end
    end
  end

  context 'when the migration failed' do
    context 'and the migration is not an alter table statement' do
      let(:version) { 8 }

      before { ActiveRecord::Base.connection.create_table(:things) }

      it 'raises and halts the execution' do
        expect do
          run_a_migration(direction, version)
        end.to raise_error do |exception|
          exception.cause == ActiveRecord::StatementInvalid
        end
      end
    end

    context 'and the migration is an alter table statement' do
      let(:version) { 1 }

      before do
        ActiveRecord::Base.connection
          .add_column(:comments, :some_id_field, :integer)
      end

      it 'raises and halts the execution' do
        expect do
          ActiveRecord::Migrator.run(direction, migration_fixtures, ActiveRecord::SchemaMigration, version)
        end.to raise_error do |exception|
          exception.cause == Departure::SignalError
        end
      end
    end
  end

  context 'when pt-online-schema-change is not installed' do
    let(:version) { 1 }

    it 'raises and halts the execution' do
      expect do
        ClimateControl.modify PATH: '' do
          run_a_migration(direction, version)
        end
      end.to raise_error do |exception|
        exception.cause == Departure::CommandNotFoundError
      end
    end
  end

  context 'when PERCONA_ARGS is specified' do
    let(:command) { instance_double(Departure::Command, run: status) }
    let(:status) do
      instance_double(Process::Status, signaled?: false, exitstatus: 1, success?: true)
    end

    context 'and only argument is provided' do
      it 'runs pt-online-schema-change with the specified arguments' do
        expect(Departure::Command)
          .to receive(:new)
          .with(/--chunk-time=1/, anything, anything, anything)
          .and_return(command)

        ClimateControl.modify PERCONA_ARGS: '--chunk-time=1' do
          run_a_migration(direction, 1)
        end
      end
    end

    context 'and multiple arguments are provided' do
      it 'runs pt-online-schema-change with the specified arguments' do
        expect(Departure::Command)
          .to receive(:new)
          .with(/--chunk-time=1 --max-lag=2/, anything, anything, anything)
          .and_return(command)

        ClimateControl.modify PERCONA_ARGS: '--chunk-time=1 --max-lag=2' do
          run_a_migration(direction, 1)
        end
      end
    end

    context 'and there is a default value for the argument' do
      it 'runs pt-online-schema-change with the user specified value' do
        expect(Departure::Command)
          .to receive(:new)
          .with(/--alter-foreign-keys-method=drop_swap/, anything, anything, anything)
          .and_return(command)

        ClimateControl.modify PERCONA_ARGS: '--alter-foreign-keys-method=drop_swap' do
          run_a_migration(direction, 1)
        end
      end
    end
  end

  context 'when there are migrations that do not use departure' do
    it 'uses Departure::OriginalConnectionAdapter' do
      establish_percona_connection
      expect(Departure::OriginalAdapterConnection).to receive(:establish_connection)

      run_a_migration(direction, 29) # DisableDeparture
    end
  end
end
