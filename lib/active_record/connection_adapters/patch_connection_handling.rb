# frozen_string_literal: true

require 'active_record/connection_handling'

module ActiveRecord
  module ConnectionHandling
    # Establishes a connection to the database that's used by all Active
    # Record objects.
    def percona_connection(config)
      config = config.dup
      original_adapter = config.delete(:departure_original_adapter)
      config[:username] ||= 'root'

      Departure::RailsAdapter
        .for_current(db_connection_adapter: original_adapter)
        .create_connection_adapter(**config)
    end
  end
end
