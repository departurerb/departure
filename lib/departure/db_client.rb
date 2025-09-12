require 'open3'

require 'forwardable'

module Departure
  # It executes pt-online-schema-change commands in a new process and gets its
  # output and status
  class DbClient
    extend ::Forwardable

    delegate_missing_to :@database_client

    def initialize(config, db_client_klass = Mysql2::Client)
      @config = config

      @database_client = db_client_klass.new(config)
    end

    # Intercepts raw query calls to pass ALTER TABLE statements to pt-online-schema-change
    # otherwise sends to
    # eg: goes to pt-online-schema-change
    #   query("ALTER TABLE `comments` ADD INDEX `index_comments_on_some_id_field` (`some_id_field`))
    # eg: sends to database adapter
    #   query("COMMIT") - query("SELECT * from 'comments'")
    def query(raw_sql_string, **options)
      if alter_statement?(raw_sql_string)
        send_to_pt_online_schema_change(raw_sql_string)
      else
        @database_client.query(raw_sql_string, **options)
      end
    end

    # Runs raw_sql_string through pt-online-schema-change command line tool
    def send_to_pt_online_schema_change(raw_sql_string)
      connection_details = Departure::ConnectionDetails.new(@config)
      sanitizers = [Departure::LogSanitizers::PasswordSanitizer.new(connection_details)]
      logger = Departure::LoggerFactory.build(sanitizers:, verbose: ActiveRecord::Migration.verbose)

      command_line = Departure::CliGenerator.new(connection_details).parse_statement(raw_sql_string)

      command = Command.new(command_line, Departure.configuration.error_log_path, logger, Departure.configuration.redirect_stderr)
      handle_command_execution(command.run)
    end

    def handle_command_execution(result)
      if result.exitstatus != 0
        raise StandardError.new(result)
      end
    end

    def alter_statement?(raw_sql_string)
      raw_sql_string =~ /\Aalter table/i
    end
  end
end
