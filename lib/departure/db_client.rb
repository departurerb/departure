require 'open3'

require 'forwardable'

module Departure
  # It executes pt-online-schema-change commands in a new process and gets its
  # output and status
  class DbClient
    delegate_missing_to :database_client

    attr_reader :database_client

    # Constructor
    #
    # @param logger [#say, #write]
    # @param cli_generator [CliGenerator]
    # @param mysql_adapter [ActiveRecord::ConnectionAdapter] it must implement
    #   #execute and #raw_connection
    def initialize(logger, cli_generator, database_client, config = Departure.configuration)
      @logger = logger
      @cli_generator = cli_generator
      @database_client = database_client
      @error_log_path = config&.error_log_path
      @redirect_stderr = config&.redirect_stderr
    end

    # Intercepts raw query calls to pass ALTER TABLE statements to pt-online-schema-change
    # otherwise sends to
    # eg: goes to pt-online-schema-change
    #   query("ALTER TABLE `comments` ADD INDEX `index_comments_on_some_id_field` (`some_id_field`))
    # eg: sends to database adapter
    #   query("COMMIT") - query("SELECT * from 'comments'")
    def query(raw_sql_string)
      if alter_statement?(raw_sql_string)
        command_line = @cli_generator.parse_statement(raw_sql_string)
        send_to_pt_online_schema_change(command_line)
      else
        database_client.query(raw_sql_string)
      end
    end

    # Runs raw_sql_string through pt-online-schema-change command line tool
    def send_to_pt_online_schema_change(raw_sql_string)
      Command.new(raw_sql_string, @error_log_path, @logger, @redirect_stderr).run
    end

    private

    # Checks whether the sql statement is an ALTER TABLE
    def alter_statement?(raw_sql_string)
      raw_sql_string =~ /\Aalter table/i
    end
  end
end
