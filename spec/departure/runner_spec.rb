require 'spec_helper'
require 'tempfile'

describe Departure::Runner do
  let(:command_line) { 'pt-online-schema-change command' }
  let(:logger) { instance_double(Departure::Logger) }
  let(:cli_generator) { instance_double(Departure::CliGenerator) }
  let(:mysql_adapter) do
    instance_double(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
  end
  let(:config) do
    instance_double(
      Departure::Configuration,
      error_log_path: 'departure_error.log',
      redirect_stderr: true
    )
  end

  let(:runner) { described_class.new(logger, cli_generator, mysql_adapter, config) }

  describe '#query' do # rubocop:disable Lint/EmptyBlock
  end

  describe '#affected_rows' do
    let(:mysql_client) { double(:mysql_client) }

    before do
      allow(mysql_adapter).to receive(:raw_connection).and_return(mysql_client)
    end

    it 'delegates to the MySQL adapter\'s client' do
      expect(mysql_client).to receive(:affected_rows)
      runner.affected_rows
    end
  end

  describe '#execute' do
    let(:status) { instance_double(Process::Status) }
    let(:cmd) { instance_double(Departure::Command, run: status) }

    before do
      allow(Departure::Command)
        .to receive(:new).with(command_line, config.error_log_path, logger, config.redirect_stderr)
        .and_return(cmd)
    end

    it 'executes the pt-online-schema-change command' do
      runner.execute(command_line)
      expect(cmd).to have_received(:run)
    end

    it 'returns the command status' do
      expect(runner.execute(command_line)).to eq(status)
    end
  end
end
