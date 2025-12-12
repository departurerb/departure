module Departure
  class Configuration
    attr_accessor :tmp_path, :global_percona_args, :enabled_by_default, :redirect_stderr,
                  :disable_rails_advisory_lock_patch, :db_adapter_name

    def initialize
      @tmp_path = '.'.freeze
      @error_log_filename = 'departure_error.log'.freeze
      @global_percona_args = nil
      @enabled_by_default = true
      @redirect_stderr = true
      @db_adapter_name = nil
    end

    def error_log_path
      File.join(tmp_path, error_log_filename)
    end

    private

    attr_reader :error_log_filename
  end
end
