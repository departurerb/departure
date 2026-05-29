module Departure
  class Error < StandardError; end

  # Used when for whatever reason we couldn't get the spawned process'
  # status.
  class NoStatusError < Error
    def message
      "Status could not be retrieved".freeze
    end
  end

  # Used when the spawned process failed by receiving a signal.
  # pt-online-schema-change returns "SIGSEGV (signal 11)" on failures.
  class SignalError < Error
    attr_reader :status

    # Constructor
    #
    # @param status [Process::Status]
    def initialize(status)
      super
      @status = status
    end

    def message
      status.to_s
    end
  end

  class CommandNotFoundError < Error
    def message
      "Please install pt-online-schema-change. Check: https://www.percona.com/doc/percona-toolkit for further details"
    end
  end

  # Used to prevent running the db:migrate rake task when providing arguments
  # through PERCONA_ARGS env var
  class ArgumentsNotSupported < Error; end
end
