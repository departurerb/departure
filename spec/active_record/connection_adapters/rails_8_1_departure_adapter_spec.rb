require 'spec_helper'
require 'active_record/connection_adapters/rails_8_1_departure_adapter'

describe ActiveRecord::ConnectionAdapters::Rails81DepartureAdapter, activerecord_compatibility: RAILS_8_1 do
  let(:adapter) { described_class.new(db_config_for(adapter: 'mysql2')) }
  let(:client) { described_class.new_client(db_config_for(adapter: 'mysql2')) }

  describe '#new_client' do
    it 'wraps the underlying db_client and exposes a mysql_client' do
      expect(client).to be_a(Departure::DbClient)
      expect(client.database_client).to be_a(Mysql2::Client)
    end
  end
end
