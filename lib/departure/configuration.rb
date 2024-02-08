module Departure
  class Configuration
    SUPPORTED_ADAPTERS = %i[trilogy mysql2].freeze

    attr_accessor :tmp_path, :global_percona_args, :enabled_by_default, :redirect_stderr
    attr_reader :adapter

    def initialize
      @tmp_path = '.'.freeze
      @error_log_filename = 'departure_error.log'.freeze
      @global_percona_args = nil
      @enabled_by_default = true
      @redirect_stderr = true
      @adapter = :mysql2
    end

    def error_log_path
      File.join(tmp_path, error_log_filename)
    end

    def adapter=(name)
      if SUPPORTED_ADAPTERS.include?(name)
        @adapter = name
      else
        raise ArgumentError, "Supported Departure adapters are #{SUPPORTED_ADAPTERS.inspect}"
      end
    end

    private

    attr_reader :error_log_filename
  end
end
