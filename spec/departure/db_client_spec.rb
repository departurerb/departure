require 'spec_helper'
require 'tempfile'

describe Departure::DbClient do
  let(:db_config) do
    { adapter: 'percona', host: 'db', username: 'root', password: nil, database: 'departure_test', flags: 2 }
  end

  let(:database_client) { instance_double(::Mysql2::Client) }

  let(:cmd) { instance_double(Departure::Command, run: status) }
  let(:status) { instance_double(Process::Status) }

  let(:instance) { described_class.new(db_config, database_client) }

  let(:alter_db_statement) { 'ALTER TABLE comments ADD `some_identifier` INT(11) DEFAULT NULL;' }
  let(:commit_db_statement) { 'commit;' }

  describe 'send_to_pt_online_schema_change' do
    it 'parses and sends to the command object' do
      expect(Departure::Command)
        .to receive(:new).with(instance_of(String), Departure.configuration.error_log_path,
                               instance_of(Departure::NullLogger), Departure.configuration.redirect_stderr)
        .and_return(cmd)
      expect(cmd).to receive(:run)

      instance.send_to_pt_online_schema_change(alter_db_statement)
    end
  end

  describe 'alter_statement?' do
    it 'true when begins with alter table' do
      expect(instance.alter_statement?(alter_db_statement)).to be_truthy
    end

    it 'false when does not begin with alter table statement' do
      expect(instance.alter_statement?(commit_db_statement)).to be_falsey
    end
  end

  describe '#query' do
    let(:status) { instance_double(Process::Status) }

    it 'delegates to the database_client when we do not have an alter statement' do
      expect(database_client).to receive(:query).with(commit_db_statement)

      instance.query(commit_db_statement)
    end

    it 'runs alter statements through departure command' do
      expect(Departure::Command)
        .to receive(:new).with(instance_of(String), Departure.configuration.error_log_path,
                               instance_of(Departure::NullLogger), Departure.configuration.redirect_stderr)
                         .and_return(cmd)
      expect(cmd).to receive(:run)

      instance.query(alter_db_statement)
    end
  end
end
