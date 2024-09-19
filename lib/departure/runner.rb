require 'open3'

module Departure
  # It executes pt-online-schema-change commands in a new process and gets its
  # output and status
  class Runner
    # Constructor
    #
    # @param logger [#say, #write]
    # @param cli_generator [CliGenerator]
    # @param mysql_adapter [ActiveRecord::ConnectionAdapter] it must implement
    #   #execute and #raw_connection
    def initialize(logger, cli_generator, mysql_adapter, config = Departure.configuration)
      @logger = logger
      @cli_generator = cli_generator
      @mysql_adapter = mysql_adapter
      @error_log_path = config.error_log_path
      @redirect_stderr = config.redirect_stderr
    end

    # Executes the passed sql statement using pt-online-schema-change for ALTER
    # TABLE statements, or the specified mysql adapter otherwise.
    #
    # @param sql [String]
    def query(sql)
      if alter_statement?(sql)
        command_line = cli_generator.parse_statement(sql)
        execute(command_line)
        affected_rows
      else
        mysql_adapter.execute(sql)
      end
    end

    # Returns the number of rows affected by the last UPDATE, DELETE or INSERT
    # statements
    #
    # @return [Integer]
    def affected_rows
      mysql_adapter.raw_connection.affected_rows
    end

    if ActiveRecord::VERSION::MAJOR >= 7 && ActiveRecord::VERSION::MINOR >= 2
      def escape(str)
        mysql_adapter.raw_connection.escape(str)
      end

      def abandon_results!
        mysql_adapter.raw_connection.abandon_results!
      end
    end

    # TODO: rename it so we don't confuse it with AR's #execute
    # Runs and logs the given command
    #
    # @param command_line [String]
    # @return [Boolean]
    def execute(command_line)
      Command.new(command_line, error_log_path, logger, redirect_stderr).run
    end

    private

    attr_reader :logger, :cli_generator, :mysql_adapter, :error_log_path, :redirect_stderr

    # Checks whether the sql statement is an ALTER TABLE
    #
    # @param sql [String]
    # @return [Boolean]
    def alter_statement?(sql)
      sql =~ /\Aalter table/i
    end
  end
end
