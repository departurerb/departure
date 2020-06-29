module Departure
  class ConnectionBase < ActiveRecord::Base
    def self.establish_connection(config = nil)
      super.tap do
        ActiveRecord::Base.connection_specification_name = connection_specification_name
      end
    end
  end

  class ConnectionOfflineBase < ConnectionBase
  end
end
