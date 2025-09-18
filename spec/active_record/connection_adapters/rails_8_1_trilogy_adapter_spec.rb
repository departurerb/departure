require 'spec_helper'
require 'active_record/connection_adapters/rails_8_1_trilogy_adapter'

describe ActiveRecord::ConnectionAdapters::Rails81TrilogyAdapter, activerecord_compatibility: RAILS_8_1 do
  let(:adapter) { described_class.new(db_config_for(adapter: 'trilogy')) }
  let(:client) { described_class.new_client(db_config_for(adapter: 'trilogy')) }
  describe '#new_client' do
    it 'wraps the underlying db_client and exposes a mysql_client' do
      trilogy_double = instance_double(::Trilogy)
      expect_any_instance_of(::Trilogy).to receive(:_connect) { trilogy_double }

      expect(client).to be_a(Departure::DbClient)
      expect(client.database_client).to be_a(::Trilogy)
    end
  end
end
