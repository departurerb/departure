require 'departure/dsn'
require 'departure/option'
require 'departure/alter_argument'
require 'departure/connection_details'
require 'departure/user_options'

module Departure
  # Generates the equivalent Percona's pt-online-schema-change command to the
  # given SQL statement
  #
  # --no-check-alter is used to allow running CHANGE COLUMN statements. For more details, check:
  # www.percona.com/doc/percona-toolkit/2.2/pt-online-schema-change.html#cmdoption-pt-online-schema-change--[no]check-alter # rubocop:disable Layout/LineLength
  #
  class CliGenerator
    COMMAND_NAME = 'pt-online-schema-change'.freeze
    DEFAULT_OPTIONS = Set.new(
      [
        Option.new('execute'),
        Option.new('statistics'),
        Option.new('alter-foreign-keys-method', 'auto'),
        Option.new('no-check-alter')
      ]
    ).freeze

    # TODO: Better doc.
    #
    # Constructor. Specify any arguments to pass to pt-online-schema-change
    # passing the PERCONA_ARGS env var when executing the migration
    #
    # @param connection_data [Hash]
    def initialize(connection_details)
      @connection_details = connection_details
    end

    # Generates the percona command. Fills all the connection credentials from
    # the current AR connection, but that can be amended via ENV-vars:
    # PERCONA_DB_HOST, PERCONA_DB_USER, PERCONA_DB_PASSWORD, PERCONA_DB_NAME
    # Table name can't not be amended, it populates automatically from the
    # migration data
    #
    # @param table_name [String]
    # @param statement [String] MySQL statement
    # @return [String]
    def generate(table_name, statement)
      alter_argument = AlterArgument.new(statement)
      dsn = DSN.new(connection_details.database, table_name)

      "#{command} #{all_options} #{dsn} #{alter_argument}"
    end

    # Generates the percona command for a raw MySQL statement. Fills all the
    # connection credentials from the current AR connection, but that can
    # amended via ENV-vars: PERCONA_DB_HOST, PERCONA_DB_USER,
    # PERCONA_DB_PASSWORD, PERCONA_DB_NAME Table name can't not be amended, it
    # populates automatically from the migration data
    #
    # @param statement [String] MySQL statement
    # @return [String]
    def parse_statement(statement)
      alter_argument = AlterArgument.new(statement)
      dsn = DSN.new(connection_details.database, alter_argument.table_name)

      "#{command} #{all_options} #{dsn} #{alter_argument}"
    end

    private

    attr_reader :connection_details

    def command
      "#{COMMAND_NAME} #{connection_details}"
    end

    # Returns all the arguments to execute pt-online-schema-change with
    #
    # @return [String]
    def all_options
      env_variable_options = UserOptions.new
      global_configuration_options = UserOptions.new(Departure.configuration.global_percona_args)
      options = env_variable_options.merge(global_configuration_options).merge(DEFAULT_OPTIONS)
      options.to_a.join(' ')
    end
  end
end
