require "active_record/connection_adapters/abstract_mysql_adapter"
require "active_record/connection_adapters/trilogy_adapter"
require "active_record/connection_adapters/patch_connection_handling"
require "departure"
require "active_record/connection_adapters/departure_adapter_behavior"

module ActiveRecord
  module ConnectionAdapters
    class Rails81TrilogyAdapter < ActiveRecord::ConnectionAdapters::TrilogyAdapter
      class Column < ActiveRecord::ConnectionAdapters::MySQL::Column
        def adapter
          Rails81TrilogyAdapter
        end
      end

      ADAPTER_NAME = "Percona".freeze

      include DepartureAdapterBehavior::Rails8
    end
  end
end
