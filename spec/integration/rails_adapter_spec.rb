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

    def instance_for(version, db_connection_adapter = 'mysql2')
      described_class.for(gem_version_for(version), db_connection_adapter:)
    end

    context 'rails 8.1 adapter' do
      describe 'returns trilogy adapter' do
        it 'when the config specifies an adapter of trilogy' do
          expect(instance_for('8.1.0', 'trilogy')).to be(Departure::RailsAdapter::V8_1_TrilogyAdapter)
        end
      end

      describe 'returns mysql2 adapter' do
        it 'by default' do
          expect(instance_for('8.1.0')).to be(Departure::RailsAdapter::V8_1_Mysql2Adapter)
          expect(instance_for('8.1.0.beta1')).to be(Departure::RailsAdapter::V8_1_Mysql2Adapter)
        end

        it 'when the config specifies an adapter of mysql2' do
          expect(instance_for('8.1.0', 'mysql2')).to be(Departure::RailsAdapter::V8_1_Mysql2Adapter)
        end

        it 'when the config specifies anything else' do
          expect(instance_for('8.1.0', 'percona')).to be(Departure::RailsAdapter::V8_1_Mysql2Adapter)
        end
      end
    end

    it 'returns the correct adapater based on the gem version' do
      expect(instance_for('8.0.1')).to be(Departure::RailsAdapter::V8_0_Adapter)
      expect(instance_for('8.0.0')).to be(Departure::RailsAdapter::V8_0_Adapter)
      expect(instance_for('7.2.0')).to be(Departure::RailsAdapter::V7_2_Adapter)
    end

    it 'raises an exception for older versiosn of rails' do
      expect { instance_for('7.1.0') }.to raise_error(Departure::RailsAdapter::UnsupportedRailsVersionError)
      expect { instance_for('6.1.0') }.to raise_error(Departure::RailsAdapter::UnsupportedRailsVersionError)
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

  describe '.register_integrations' do
    it 'delegates to the adapter for the current Rails version' do
      adapter_class = described_class.for_current
      expect(adapter_class).to receive(:register_integrations)

      described_class.register_integrations
    end

    it 'passes through keyword arguments to the adapter' do
      expect(described_class).to receive(:for_current).with(db_connection_adapter: 'trilogy').and_call_original
      adapter_class = described_class.for_current(db_connection_adapter: 'trilogy')
      allow(described_class).to receive(:for_current).with(db_connection_adapter: 'trilogy').and_return(adapter_class)
      expect(adapter_class).to receive(:register_integrations)

      described_class.register_integrations(db_connection_adapter: 'trilogy')
    end

    context 'when called on specific adapters' do
      it 'requires the correct adapter file and registers components for V7_2_Adapter' do
        expect(described_class::V7_2_Adapter).to receive(:require).with('active_record/connection_adapters/rails_7_2_departure_adapter')
        expect(described_class::V7_2_Adapter).to receive(:require).with('departure/rails_patches/active_record_migrator_with_advisory_lock_patch')
        expect(ActiveRecord::Migration).to receive(:class_eval)
        expect(ActiveRecord::Migrator).to receive(:prepend).with(Departure::RailsPatches::ActiveRecordMigratorWithAdvisoryLockPatch)
        expect(ActiveRecord::ConnectionAdapters).to receive(:register).with(
          'percona',
          'ActiveRecord::ConnectionAdapters::Rails72DepartureAdapter',
          'active_record/connection_adapters/rails_7_2_departure_adapter'
        )

        described_class::V7_2_Adapter.register_integrations
      end

      it 'requires the correct adapter file and registers components for V8_0_Adapter' do
        expect(described_class::V8_0_Adapter).to receive(:require).with('active_record/connection_adapters/rails_8_0_departure_adapter')
        expect(described_class::V8_0_Adapter).to receive(:require).with('departure/rails_patches/active_record_migrator_with_advisory_lock_patch')
        expect(ActiveRecord::Migration).to receive(:class_eval)
        expect(ActiveRecord::Migrator).to receive(:prepend).with(Departure::RailsPatches::ActiveRecordMigratorWithAdvisoryLockPatch)
        expect(ActiveRecord::ConnectionAdapters).to receive(:register).with(
          'percona',
          'ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter',
          'active_record/connection_adapters/rails_8_0_departure_adapter'
        )

        described_class::V8_0_Adapter.register_integrations
      end

      it 'requires the correct adapter file and registers components for V8_1_Mysql2Adapter' do
        expect(described_class::V8_1_Mysql2Adapter).to receive(:require).with('active_record/connection_adapters/rails_8_1_mysql2_adapter')
        expect(described_class::V8_1_Mysql2Adapter).to receive(:require).with('departure/rails_patches/active_record_migrator_with_advisory_lock_patch')
        expect(ActiveRecord::Migration).to receive(:class_eval)
        expect(ActiveRecord::Migrator).to receive(:prepend).with(Departure::RailsPatches::ActiveRecordMigratorWithAdvisoryLockPatch)
        expect(ActiveRecord::ConnectionAdapters).to receive(:register).with(
          'percona',
          'ActiveRecord::ConnectionAdapters::Rails81Mysql2Adapter',
          'active_record/connection_adapters/rails_8_1_mysql2_adapter'
        )

        described_class::V8_1_Mysql2Adapter.register_integrations
      end

      it 'requires the correct adapter file and registers components for V8_1_TrilogyAdapter' do
        expect(described_class::V8_1_TrilogyAdapter).to receive(:require).with('active_record/connection_adapters/rails_8_1_trilogy_adapter')
        expect(described_class::V8_1_TrilogyAdapter).to receive(:require).with('departure/rails_patches/active_record_migrator_with_advisory_lock_patch')
        expect(ActiveRecord::Migration).to receive(:class_eval)
        expect(ActiveRecord::Migrator).to receive(:prepend).with(Departure::RailsPatches::ActiveRecordMigratorWithAdvisoryLockPatch)
        expect(ActiveRecord::ConnectionAdapters).to receive(:register).with(
          'percona',
          'ActiveRecord::ConnectionAdapters::Rails81TrilogyAdapter',
          'active_record/connection_adapters/rails_8_1_trilogy_adapter'
        )

        described_class::V8_1_TrilogyAdapter.register_integrations
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
