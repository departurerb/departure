require "active_record/connection_adapters/abstract_mysql_adapter"
require "active_record/connection_adapters/mysql2_adapter"
require "active_record/connection_adapters/patch_connection_handling"
require "departure"
require "active_record/connection_adapters/departure_adapter_behavior"

module ActiveRecord
  module ConnectionAdapters
    class Rails81Mysql2Adapter < ActiveRecord::ConnectionAdapters::Mysql2Adapter
      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) } if defined?(initialize_type_map)

      class Column < ActiveRecord::ConnectionAdapters::MySQL::Column
        def adapter
          Rails81Mysql2Adapter
        end
      end

      ADAPTER_NAME = "Percona".freeze

      include DepartureAdapterBehavior::Rails8
    end
  end
end
