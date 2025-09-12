require 'open3'

require 'forwardable'

module Departure
  # It executes pt-online-schema-change commands in a new process and gets its
  # output and status
  class DbClient
    extend ::Forwardable

    # These are methods we know will be sent to the raw_connection
    # other methods are forwarded to the raw_connection, database_adapter or supered
    def_delegators :raw_connection, :server_info, :execute, :escape, :close, :affected_rows, :closed?

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
      @error_log_path = config&.error_log_path
      @redirect_stderr = config&.redirect_stderr
    end

    def query_options
      raw_connection.query_options
    end

    def abandon_results!
      raw_connection.abandon_results!
    end

    def database_adapter
      @mysql_adapter
    end

    def raw_connection
      database_adapter.raw_connection
    end

    # Intercepts raw query calls to pass ALTER TABLE statements to pt-online-schema-change
    # otherwise sends to
    # eg: goes to pt-online-schema-change
    #   query("ALTER TABLE `comments` ADD INDEX `index_comments_on_some_id_field` (`some_id_field`))
    # eg: sends to database adapter
    #   query("COMMIT") - query("SELECT * from 'comments'")
    def query(raw_sql_string)
      # binding.pry if sql.include? "index"
      if alter_statement?(raw_sql_string)
        command_line = cli_generator.parse_statement(raw_sql_string)
        send_to_pt_online_schema_change(command_line)
      else
        database_adapter.execute(raw_sql_string)
      end
    end

    # Runs raw_sql_string through pt-online-schema-change command line tool
    def send_to_pt_online_schema_change(raw_sql_string)
      Command.new(raw_sql_string, error_log_path, logger, redirect_stderr).run
    end

    private

    attr_reader :logger, :cli_generator, :mysql_adapter, :error_log_path, :redirect_stderr

    # This runner forwards missing methods to both the raw_connection and database adapter
    def method_missing(method_name, *args, &block)
      if raw_connection.respond_to?(method_name)
        raw_connection.send(method_name, *args, &block)
      elsif database_adapter.respond_to?(method_name)
        database_adapter.send(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      raw_connection.respond_to?(method_name) || database_adapter.respond_to?(method_name) || super
    end

    # Checks whether the sql statement is an ALTER TABLE
    #
    # @param sql [String]
    # @return [Boolean]
    def alter_statement?(raw_sql_string)
      raw_sql_string =~ /\Aalter table/i
    end
  end
end
