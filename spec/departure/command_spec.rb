require 'spec_helper'

describe Departure::Command do
  shared_examples_for '#run' do
    let(:command) { 'pt-online-schema-change command' }
    let(:error_log_path) { 'departure_error.log' }
    let(:logger) do
      instance_double(
        Departure::Logger, write: true, say: true, write_no_newline: true
      )
    end

    let(:runner) { described_class.new(command, error_log_path, logger, redirect_stderr) }

    let(:temp_file) do
      file = Tempfile.new('faked_stdout')
      file.write('hello world\ntodo roto')
      file.rewind
      file.close
      file
    end
    let(:status) do
      instance_double(
        Process::Status,
        exitstatus: 0,
        signaled?: false,
        success?: true
      )
    end
    let(:stdout) { temp_file.open }
    let(:wait_thread) { instance_double(Thread, value: status) }

    before do
      allow(Open3).to(
        receive(:popen3)
        .with(expected_command)
        .and_yield(nil, stdout, nil, wait_thread)
      )
    end

    it 'executes the pt-online-schema-change command' do
      runner.run
      expect(Open3).to have_received(:popen3).with(expected_command)
    end

    it 'returns the command status' do
      expect(runner.run).to eq(status)
    end

    it 'logs that the execution started' do
      runner.run
      expect(logger).to have_received(:say).with(
        "Running pt-online-schema-change command\n\n",
        true
      )
    end

    it 'logs the command\'s output' do
      runner.run

      expect(logger).to have_received(:write_no_newline).with('hello world\\ntodo roto')
    end

    context 'when not redirecting stderr' do
      let(:expected_command) { "#{command} 2>&1" }
      let(:redirect_stderr) { false }

      it 'executes the expected command' do
        runner.run
        expect(Open3).to have_received(:popen3).with(expected_command)
      end
    end

    context 'on failure' do
      before do
        allow(Open3).to(
          receive(:popen3)
          .with(expected_command)
          .and_call_original
        )
      end

      context 'when the execution failed' do
        let(:command) { 'sh -c \'echo ROTO >/dev/stderr && false\'' }

        it 'raises a Departure::Error' do
          expect { runner.run }
            .to raise_exception(Departure::Error, redirect_stderr ? "ROTO\n" : '')
        end
      end

      context 'when the command was signaled' do
        let(:command) { 'kill -9 $$' }

        it 'raises a SignalError specifying the status' do
          expect { runner.run }
            .to raise_exception(Departure::SignalError)
        end
      end

      context 'when pt-online-schema-change is not installed' do
        let(:command) { 'whatevarrr666' }

        it 'raises a detailed CommandNotFoundError' do
          expect { runner.run }.to raise_exception(
            Departure::CommandNotFoundError,
            /Please install pt-online-schema-change/
          )
        end
      end
    end
  end

  context 'redirect_stderr = true' do
    let(:redirect_stderr) { true }
    let(:expected_command) { "#{command} 2> #{error_log_path}" }

    it_should_behave_like '#run'
  end

  context 'redirect_stderr = false' do
    let(:redirect_stderr) { false }
    let(:expected_command) { "#{command} 2>&1" }

    it_should_behave_like '#run'
  end
end
