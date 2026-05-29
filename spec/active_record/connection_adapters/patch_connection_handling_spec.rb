require "spec_helper"
require "active_record/connection_adapters/patch_connection_handling"

describe ActiveRecord::ConnectionHandling do
  describe "#percona_connection" do
    it "selects the departure adapter from the original database adapter name" do
      adapter_class = class_double(Departure::RailsAdapter::V8_1_TrilogyAdapter)
      config = {
        adapter: "percona",
        database: "departure_test",
        departure_original_adapter: "trilogy",
        username: "root"
      }
      adapter_config = {
        adapter: "percona",
        database: "departure_test",
        username: "root"
      }

      expect(Departure::RailsAdapter)
        .to receive(:for_current)
        .with(db_connection_adapter: "trilogy")
        .and_return(adapter_class)
      expect(adapter_class)
        .to receive(:create_connection_adapter)
        .with(**adapter_config)
        .and_return(:connection_adapter)

      expect(ActiveRecord::Base.percona_connection(config)).to eq(:connection_adapter)
    end
  end
end
