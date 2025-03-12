# frozen_string_literal: true

require 'active_record/connection_handling'

module ActiveRecord
  module ConnectionHandling
    # Establishes a connection to the database that's used by all Active
    # Record objects.
    def percona_connection(config)
      if config[:username].nil?
        config = config.dup if config.frozen?
        config[:username] = 'root'
      end

      Departure::RailsIntegrator.for_current.create_connection_adapter(**config)
    end
  end
end
