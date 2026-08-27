require "spec_helper"
require "fileutils"
require "tmpdir"

# TODO: Handle #change_table syntax
describe Departure, integration: true do
  let(:direction) { :up }
  let(:spec_config) { ActiveRecord::Base.connection_db_config.configuration_hash.symbolize_keys }

  it "has a version number" do
    expect(Departure::VERSION).not_to be nil
  end

  describe "logging" do
    context "when the migration logging is disabled" do
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

    context "when the migration logging is enabled" do
      around(:each) do |example|
        original_verbose = ActiveRecord::Migration.verbose
        ActiveRecord::Migration.verbose = true
        example.run
        ActiveRecord::Migration.verbose = original_verbose
      end

      it "sends the output to stdout" do
        expect do
          run_a_migration(direction, 1)
        end.to output.to_stdout
      end
    end
  end

  context "when ActiveRecord is loaded" do
    let(:db_config) { app_database_config }

    it "uses PerconaAdapter while preserving the application connection" do
      departure_adapter = (ENV.fetch("DB_ADAPTER", "mysql2") == "trilogy") ? "percona_trilogy" : "percona"

      expect(Departure::ConnectionBase)
        .to receive(:establish_connection)
        .with(hash_including(adapter: departure_adapter))
        .and_call_original

      run_a_migration(direction, 1)

      expect(spec_config[:adapter]).to eq(ENV.fetch("DB_ADAPTER", "mysql2"))
    end

    context "when a username is provided" do
      before do
        establish_percona_connection(username: db_config["username"])
      end

      it "uses the provided username" do
        run_a_migration(direction, 1)
        expect(spec_config[:username]).to eq("root")
      end
    end

    it "runs an Lhm DSL migration through the railtie-patched migration runner" do
      migrations_path = Dir.mktmpdir("departure-lhm-migrations")

      migration_version = ActiveRecord::VERSION::STRING.split(".").first(2).join(".")

      File.write(
        File.join(migrations_path, "20260101000000_lhm_add_column.rb"),
        <<~RUBY
          class LhmAddColumn < ActiveRecord::Migration[#{migration_version}]
            def up
              Lhm.change_table(:comments) do |t|
                t.add_column(:some_id_field, :integer)
              end
            end

            def down
              Lhm.change_table(:comments) do |t|
                t.remove_column(:some_id_field)
              end
            end
          end
        RUBY
      )

      context = ActiveRecord::MigrationContext.new([migrations_path], ActiveRecord::SchemaMigration)
      context.run(:up, 20_260_101_000_000)

      expect(:comments).to have_column("some_id_field")

      context.run(:down, 20_260_101_000_000)

      expect(:comments).not_to have_column("some_id_field")
    ensure
      FileUtils.remove_entry(migrations_path) if migrations_path
    end
  end

  context "when the migration failed" do
    context "and the migration is not an alter table statement" do
      let(:version) { 8 }

      before { ActiveRecord::Base.connection.create_table(:things) }

      it "raises and halts the execution" do
        expect do
          run_a_migration(direction, version)
        end.to raise_error do |exception|
          exception.cause == ActiveRecord::StatementInvalid
        end
      end
    end

    context "and the migration is an alter table statement" do
      let(:version) { 1 }

      before do
        ActiveRecord::Base.connection
          .add_column(:comments, :some_id_field, :integer)
      end

      it "raises and halts the execution" do
        expect do
          ActiveRecord::Migrator.run(direction, migration_fixtures, ActiveRecord::SchemaMigration, version)
        end.to raise_error do |exception|
          exception.cause == Departure::SignalError
        end
      end
    end
  end

  context "when pt-online-schema-change is not installed" do
    let(:version) { 1 }

    it "raises and halts the execution" do
      expect do
        ClimateControl.modify PATH: "" do
          run_a_migration(direction, version)
        end
      end.to raise_error do |exception|
        exception.cause == Departure::CommandNotFoundError
      end
    end
  end

  context "when PERCONA_ARGS is specified" do
    let(:command) { instance_double(Departure::Command, run: status) }
    let(:status) do
      instance_double(Process::Status, signaled?: false, exitstatus: 1, success?: true)
    end

    context "and only argument is provided" do
      it "runs pt-online-schema-change with the specified arguments" do
        expect(Departure::Command)
          .to receive(:new)
          .with(/--chunk-time=1/, anything, anything, anything)
          .and_return(command)

        ClimateControl.modify PERCONA_ARGS: "--chunk-time=1" do
          run_a_migration(direction, 1)
        end
      end
    end

    context "and multiple arguments are provided" do
      it "runs pt-online-schema-change with the specified arguments" do
        expect(Departure::Command)
          .to receive(:new)
          .with(/--chunk-time=1 --max-lag=2/, anything, anything, anything)
          .and_return(command)

        ClimateControl.modify PERCONA_ARGS: "--chunk-time=1 --max-lag=2" do
          run_a_migration(direction, 1)
        end
      end
    end

    context "and there is a default value for the argument" do
      it "runs pt-online-schema-change with the user specified value" do
        expect(Departure::Command)
          .to receive(:new)
          .with(/--alter-foreign-keys-method=drop_swap/, anything, anything, anything)
          .and_return(command)

        ClimateControl.modify PERCONA_ARGS: "--alter-foreign-keys-method=drop_swap" do
          run_a_migration(direction, 1)
        end
      end
    end
  end

  context "when there are migrations that do not use departure" do
    it "uses Departure::OriginalConnectionAdapter" do
      establish_percona_connection
      expect(Departure::OriginalAdapterConnection).to receive(:establish_connection)

      run_a_migration(direction, 29) # DisableDeparture
    end
  end
end
