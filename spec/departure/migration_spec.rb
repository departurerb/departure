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
