require 'spec_helper'

RSpec.describe Departure::RailsAdapter, integration: true do
  describe '#for' do
    def gem_version_for(string)
      major, minor, patch, pre = string.split('.')

      Class.new.tap do |klass|
        klass.const_set :MAJOR, major.to_i
        klass.const_set :MINOR, minor.to_i
        klass.const_set :PATCH, patch.to_i

        klass.const_set :PRE, pre if pre
      end
    end

    it 'returns the correct adapater based on the gem version' do
      expect(described_class.for(gem_version_for('8.1.0'))).to be(Departure::RailsAdapter::V8_1_Adapter)
      expect(described_class.for(gem_version_for('8.1.0.beta1'))).to be(Departure::RailsAdapter::V8_1_Adapter)
      expect(described_class.for(gem_version_for('8.0.1'))).to be(Departure::RailsAdapter::V8_0_Adapter)
      expect(described_class.for(gem_version_for('8.0.0'))).to be(Departure::RailsAdapter::V8_0_Adapter)
      expect(described_class.for(gem_version_for('7.2.0'))).to be(Departure::RailsAdapter::V7_2_Adapter)
    end

    it 'raises an exception on before 7.2' do
      expect do
        described_class.for(gem_version_for('7.1.0'))
      end.to raise_error(described_class::UnsupportedRailsVersionError)
      expect do
        described_class.for(gem_version_for('6.1.0'))
      end.to raise_error(described_class::UnsupportedRailsVersionError)
    end
  end

  describe '#version_matches?' do
    context 'direct matches' do
      it 'returns true when compatible' do
        expect(described_class.version_matches?('8.0.2', '8.0.2')).to be true
      end

      it 'returns false when not compatible' do
        expect(described_class.version_matches?('8.0.2', '8.0.3')).to be false
      end
    end

    context 'less than matches' do
      it 'returns true when compatible' do
        expect(described_class.version_matches?('8.0.2', '< 8.0.3')).to be true
      end

      it 'returns false when not compatible' do
        expect(described_class.version_matches?('8.0.4', '< 8.0.3')).to be false
      end
    end

    context 'squigly matches' do
      it 'returns true when compatible' do
        expect(described_class.version_matches?('7.0.2', '~> 7')).to be true
        expect(described_class.version_matches?('7.1.2', '~> 7')).to be true
        expect(described_class.version_matches?('7.1.2', '~> 7.1')).to be true
      end

      it 'returns false when not compatible' do
        expect(described_class.version_matches?('8.0.2', '~> 7.1')).to be false
      end
    end
  end

  describe 'advisory_lock patch' do
    it 'runs migrations without throwing an ActiveRecord::ConcurrentMigration Error' do
      expect { run_a_migration(:up, 1) }.not_to raise_error
    end

    it 'throws an exception when we are in rails 7.1 and have the patch disabled',
       activerecord_compatibility: '> 7.1' do
      disable_departure_rails_advisory_lock_patch

      establish_mysql_connection

      expect { run_a_migration(:up, 1) }.to raise_error(ActiveRecord::ConcurrentMigrationError)
    ensure
      enable_departure_rails_advisory_lock_patch
    end
  end
end
