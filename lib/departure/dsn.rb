module Departure
  # Represents the 'DSN' argument of Percona's pt-online-schema-change
  # See https://www.percona.com/doc/percona-toolkit/2.0/pt-online-schema-change.html#dsn-options
  class DSN
    # Constructor
    #
    # @param database [String, Symbol]
    # @param table_name [String, Symbol]
    def initialize(database, table_name)
      @database = database
      @table_name = table_name
      @suffix = ENV.fetch('PERCONA_DSN_SUFFIX', nil)
    end

    # Returns the pt-online-schema-change DSN string. See
    # https://www.percona.com/doc/percona-toolkit/2.0/pt-online-schema-change.html#dsn-options
    def to_s
      "D=#{database},t=#{table_name}#{suffix.nil? ? nil : ",#{suffix}"}"
    end

    private

    attr_reader :table_name, :database, :suffix
  end
end
