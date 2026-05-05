require 'spec_helper'

describe Departure::Migration do
  before { setup_departure_integrations }

  let(:base) do
    Class.new do
      attr_accessor :migrated_direction

      def migrate(direction)
        self.migrated_direction = direction
      end

      include Departure::Migration
    end
  end

  let(:klass) { Class.new(base) }

  subject(:migration) { klass.new }

  context 'uses_departure class attribute' do
    it 'can set default value on base class' do
      base.uses_departure = true
      expect(klass.uses_departure).to eq(true)
      expect(subject.uses_departure).to eq(true)
    end

    it 'can override on migration with uses_departure!' do
      base.uses_departure = false
      klass.uses_departure!
      expect(subject.uses_departure).to eq(true)
    end
  end

  context 'Departure enabled (uses_departure is truthy)' do
    before { klass.uses_departure! }

    it 'calls departure_migrate' do
      expect(subject).to receive(:departure_migrate).and_call_original

      subject.migrate(:up)

      expect(subject.migrated_direction).to eq(:up)
    end

    it 'uses the trilogy departure adapter when reconnecting from a trilogy database' do
      adapter_class = class_double(
        Departure::RailsAdapter::V8_1_TrilogyAdapter,
        departure_adapter_name: 'percona_trilogy'
      )

      allow(migration).to receive(:connection_config).and_return(
        adapter: 'trilogy',
        database: 'departure_test'
      )
      allow(Departure::RailsAdapter)
        .to receive(:for_current)
        .with(db_connection_adapter: 'trilogy')
        .and_return(adapter_class)

      expect(Departure::ConnectionBase)
        .to receive(:establish_connection)
        .with(hash_including(adapter: 'percona_trilogy', departure_original_adapter: 'trilogy'))

      migration.reconnect_with_percona
    end
  end

  context 'Departure disabled (uses_departure falsy)' do
    before { klass.uses_departure = false }

    it 'does not call departure_migrate' do
      expect(subject).to_not receive(:departure_migrate)

      subject.migrate(:up)

      expect(subject.migrated_direction).to eq(:up)
    end
  end
end
