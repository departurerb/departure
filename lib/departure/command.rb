module Departure
  # Executes the given command returning it's status and errors
  class Command
    COMMAND_NOT_FOUND = 127

    # Constructor
    #
    # @param command_line [String]
    # @param error_log_path [String]
    # @param logger [#write_no_newline]
    def initialize(command_line, error_log_path, logger, redirect_stderr)
      @command_line = command_line
      @error_log_path = error_log_path
      @logger = logger
      @redirect_stderr = redirect_stderr
    end

    # Executes the command returning its status. It also prints its stdout to
    # the logger and its stderr to the file specified in error_log_path.
    #
    # @raise [NoStatusError] if the spawned process' status can't be retrieved
    # @raise [SignalError] if the spawned process received a signal
    # @raise [CommandNotFoundError] if pt-online-schema-change can't be found
    #
    # @return [Process::Status]
    def run
      log_started

      run_in_process

      log_finished

      validate_status!
      status
    end

    private

    attr_reader :command_line, :error_log_path, :logger, :status, :redirect_stderr

    # Runs the command in a separate process, capturing its stdout and
    # execution status
    def run_in_process
      Open3.popen3(full_command) do |_stdin, stdout, _stderr, waith_thr|
        begin
          loop do
            stdout.wait_readable
            data = stdout.read_nonblock(8192)
            logger.write_no_newline(data)
          end
        rescue EOFError
          # noop
        ensure
          @status = waith_thr.value
        end
      end
    end

    # Builds the actual command including stderr redirection to the specified
    # log file or stdout
    #
    # @return [String]
    def full_command
      if redirect_stderr
        "#{command_line} 2> #{error_log_path}"
      else
        "#{command_line} 2>&1"
      end
    end

    # Validates the status of the execution
    #
    # @raise [NoStatusError] if the spawned process' status can't be retrieved
    # @raise [SignalError] if the spawned process received a signal
    # @raise [CommandNotFoundError] if pt-online-schema-change can't be found
    def validate_status!
      raise SignalError.new(status) if status.signaled? # rubocop:disable Style/RaiseArgs
      raise CommandNotFoundError if status.exitstatus == COMMAND_NOT_FOUND
      raise Error, error_message unless status.success?
    end

    # Returns the error message that appeared in the process' stderr
    #
    # @return [String]
    def error_message
      File.read(error_log_path)
    end

    # Logs when the execution started
    def log_started
      logger.write("\n")
      logger.say("Running #{command_line}\n\n", subitem: true)
    end

    # Prints a line break to keep the logs separate from the execution time
    # print by the migration
    def log_finished
      logger.write("\n")
    end
  end
end
