require 'shellwords'
module Departure
  # Holds the parameters of the DB connection and formats them to string
  class ConnectionDetails
    DEFAULT_PORT = 3306
    # Constructor
    #
    # @param connection_data [Hash] connection parameters as used in #establish_conneciton
    def initialize(connection_data)
      @connection_data = connection_data
    end

    # Returns the details formatted as an string to be used with
    # pt-online-schema-change. It follows the mysql client's format.
    #
    # @return [String]
    def to_s
      @to_s ||= "#{base_connection} -u #{user} #{password_argument}"
    end

    # TODO: Doesn't the abstract adapter already handle this somehow?
    # Returns the database name. If PERCONA_DB_NAME is passed its value will be
    # used instead
    #
    # Returns the database name
    #
    # @return [String]
    def database
      ENV.fetch('PERCONA_DB_NAME', connection_data[:database])
    end

    # Returns the password fragment of the details string if a password is passed
    #
    # @return [String]
    def password_argument
      if password.present?
        %(--password #{Shellwords.escape(password)} )
      else
        ''
      end
    end

    private

    attr_reader :connection_data

    # Returns conditionally host or socket configuration
    #
    # @return [String]
    def base_connection
      return socket_argument if socket.present?

      "#{host_argument} -P #{port}"
    end

    # Returns the host fragment of the details string, adds ssl options if needed
    #
    # @return [String]
    def host_argument
      host_string = host
      if ssl_ca.present?
        host_string += ";mysql_ssl=1;mysql_ssl_client_ca=#{ssl_ca}"
      end
      "-h \"#{host_string}\""
    end

    # Returns the socket fragment of the details string
    # FIXME: SSL connection
    #
    # @return [String]
    def socket_argument
      "-S #{socket}"
    end

    # Returns the database host name, defaulting to localhost. If PERCONA_DB_HOST
    # is passed its value will be used instead
    #
    # @return [String]
    def host
      ENV.fetch('PERCONA_DB_HOST', connection_data[:host]) || 'localhost'
    end

    # Returns the database user. If PERCONA_DB_USER is passed its value will be
    # used instead
    #
    # @return [String]
    def user
      ENV.fetch('PERCONA_DB_USER', connection_data[:username])
    end

    # Returns the database user's password. If PERCONA_DB_PASSWORD is passed its
    # value will be used instead
    #
    # @return [String]
    def password
      ENV.fetch('PERCONA_DB_PASSWORD', connection_data[:password])
    end

    # Returns the database socket path. If PERCONA_DB_SOCKET is passed its value
    # will be used instead
    #
    # @return [String]
    def socket
      ENV.fetch('PERCONA_DB_SOCKET', connection_data[:socket])
    end

    # Returns the database's port.
    #
    # @return [String]
    def port
      connection_data.fetch(:port, DEFAULT_PORT)
    end

    # Returns the database' SSL CA certificate.
    #
    # @return [String]
    def ssl_ca
      connection_data.fetch(:sslca, nil)
    end
  end
end
