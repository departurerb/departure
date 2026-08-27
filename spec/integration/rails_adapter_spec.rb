require "spec_helper"

RSpec.describe Departure::RailsAdapter do
  describe "#for" do
    def gem_version_for(string)
      major, minor, patch, pre = string.split(".")

      Class.new.tap do |klass|
        klass.const_set :MAJOR, major.to_i
        klass.const_set :MINOR, minor.to_i
        klass.const_set :PATCH, patch.to_i

        klass.const_set :PRE, pre if pre
      end
    end

    def instance_for(version, db_connection_adapter = "mysql2")
      described_class.for(gem_version_for(version), db_connection_adapter:)
    end

    context "rails 8.1 adapter" do
      describe "returns trilogy adapter" do
        it "when the config specifies an adapter of trilogy" do
          expect(instance_for("8.1.0", "trilogy")).to be(Departure::RailsAdapter::V8_1_TrilogyAdapter)
        end
      end

      describe "returns mysql2 adapter" do
        it "by default" do
          expect(instance_for("8.1.0")).to be(Departure::RailsAdapter::V8_1_Mysql2Adapter)
          expect(instance_for("8.1.0.beta1")).to be(Departure::RailsAdapter::V8_1_Mysql2Adapter)
        end

        it "when the config specifies an adapter of mysql2" do
          expect(instance_for("8.1.0", "mysql2")).to be(Departure::RailsAdapter::V8_1_Mysql2Adapter)
        end

        it "when the config specifies anything else" do
          expect(instance_for("8.1.0", "percona")).to be(Departure::RailsAdapter::V8_1_Mysql2Adapter)
        end
      end
    end

    it "returns the correct adapater based on the gem version" do
      expect(instance_for("8.0.1")).to be(Departure::RailsAdapter::V8_0_Adapter)
      expect(instance_for("8.0.0")).to be(Departure::RailsAdapter::V8_0_Adapter)
      expect(instance_for("7.2.0")).to be(Departure::RailsAdapter::V7_2_Adapter)
    end

    it "raises an exception for older versiosn of rails" do
      expect { instance_for("7.1.0") }.to raise_error(Departure::RailsAdapter::UnsupportedRailsVersionError)
      expect { instance_for("6.1.0") }.to raise_error(Departure::RailsAdapter::UnsupportedRailsVersionError)
    end
  end

  describe "#version_matches?" do
    context "direct matches" do
      it "returns true when compatible" do
        expect(described_class.version_matches?("8.0.2", "8.0.2")).to be true
      end

      it "returns false when not compatible" do
        expect(described_class.version_matches?("8.0.2", "8.0.3")).to be false
      end
    end

    context "less than matches" do
      it "returns true when compatible" do
        expect(described_class.version_matches?("8.0.2", "< 8.0.3")).to be true
      end

      it "returns false when not compatible" do
        expect(described_class.version_matches?("8.0.4", "< 8.0.3")).to be false
      end
    end

    context "squigly matches" do
      it "returns true when compatible" do
        expect(described_class.version_matches?("7.0.2", "~> 7")).to be true
        expect(described_class.version_matches?("7.1.2", "~> 7")).to be true
        expect(described_class.version_matches?("7.1.2", "~> 7.1")).to be true
      end

      it "returns false when not compatible" do
        expect(described_class.version_matches?("8.0.2", "~> 7.1")).to be false
      end
    end
  end

  describe ".register_integrations" do
    let(:required_paths) { [] }
    let(:registrations) { [] }

    before do
      allow(ActiveRecord::ConnectionAdapters).to receive(:register) do |*args|
        registrations << args
      end
    end

    def assert_wiring(adapter_class, expected_requires:, expected_registrations:)
      allow(adapter_class).to receive(:require) do |path|
        required_paths << path
      end

      adapter_class.register_integrations

      expect(required_paths).to include(*expected_requires)
      expect(registrations).to include(*expected_registrations)
    end

    it "wires the percona adapter for V7_2_Adapter" do
      assert_wiring(
        described_class::V7_2_Adapter,
        expected_requires: [
          "active_record/connection_adapters/rails_7_2_departure_adapter",
          "departure/rails_patches/active_record_migrator_with_advisory_lock_patch"
        ],
        expected_registrations: [
          ["percona", "ActiveRecord::ConnectionAdapters::Rails72DepartureAdapter",
            "active_record/connection_adapters/rails_7_2_departure_adapter"]
        ]
      )
    end

    it "wires the percona adapter for V8_0_Adapter" do
      assert_wiring(
        described_class::V8_0_Adapter,
        expected_requires: [
          "active_record/connection_adapters/rails_8_0_departure_adapter",
          "departure/rails_patches/active_record_migrator_with_advisory_lock_patch"
        ],
        expected_registrations: [
          ["percona", "ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter",
            "active_record/connection_adapters/rails_8_0_departure_adapter"]
        ]
      )
    end

    it "wires the percona and percona_trilogy adapters for V8_1_Mysql2Adapter" do
      assert_wiring(
        described_class::V8_1_Mysql2Adapter,
        expected_requires: [
          "active_record/connection_adapters/rails_8_1_mysql2_adapter",
          "departure/rails_patches/active_record_migrator_with_advisory_lock_patch"
        ],
        expected_registrations: [
          ["percona", "ActiveRecord::ConnectionAdapters::Rails81Mysql2Adapter",
            "active_record/connection_adapters/rails_8_1_mysql2_adapter"],
          ["percona_trilogy", "ActiveRecord::ConnectionAdapters::Rails81TrilogyAdapter",
            "active_record/connection_adapters/rails_8_1_trilogy_adapter"]
        ]
      )
    end

    it "wires the percona and percona_trilogy adapters for V8_1_TrilogyAdapter" do
      assert_wiring(
        described_class::V8_1_TrilogyAdapter,
        expected_requires: [
          "active_record/connection_adapters/rails_8_1_trilogy_adapter",
          "departure/rails_patches/active_record_migrator_with_advisory_lock_patch"
        ],
        expected_registrations: [
          ["percona", "ActiveRecord::ConnectionAdapters::Rails81Mysql2Adapter",
            "active_record/connection_adapters/rails_8_1_mysql2_adapter"],
          ["percona_trilogy", "ActiveRecord::ConnectionAdapters::Rails81TrilogyAdapter",
            "active_record/connection_adapters/rails_8_1_trilogy_adapter"]
        ]
      )
    end
  end

  describe "railtie integration" do
    def expected_adapter_class(adapter)
      {
        described_class::V7_2_Adapter => "ActiveRecord::ConnectionAdapters::Rails72DepartureAdapter",
        described_class::V8_0_Adapter => "ActiveRecord::ConnectionAdapters::Rails80DepartureAdapter",
        described_class::V8_1_Mysql2Adapter => "ActiveRecord::ConnectionAdapters::Rails81Mysql2Adapter",
        described_class::V8_1_TrilogyAdapter => "ActiveRecord::ConnectionAdapters::Rails81TrilogyAdapter"
      }.fetch(adapter)
    end

    it "registers the current version's departure adapter" do
      adapter = described_class.for_current

      expect(ActiveRecord::ConnectionAdapters.resolve(adapter.departure_adapter_name).name)
        .to eq(expected_adapter_class(adapter))
    end

    it "patches ActiveRecord::Migration with Departure::Migration" do
      expect(ActiveRecord::Migration.ancestors).to include(Departure::Migration)
    end

    it "patches ActiveRecord::Migrator with the advisory lock patch" do
      expect(ActiveRecord::Migrator.ancestors).to include(
        Departure::RailsPatches::ActiveRecordMigratorWithAdvisoryLockPatch
      )
    end

    it "registers the percona_trilogy adapter", activerecord_compatibility: RAILS_8_1 do
      expect(ActiveRecord::ConnectionAdapters.resolve("percona_trilogy").name)
        .to eq("ActiveRecord::ConnectionAdapters::Rails81TrilogyAdapter")
    end
  end

  describe "railtie configuration" do
    it "enables departure for migrations by default" do
      expect(ActiveRecord::Migration.uses_departure).to be(true)
    end

    it "sets the tmp_path from the application" do
      expect(Departure.configuration.tmp_path).to eq(Rails.root.join("tmp").to_s)
    end
  end
end

RSpec.describe Departure::RailsAdapter, integration: true do
  describe "advisory_lock patch" do
    it "runs migrations without throwing an ActiveRecord::ConcurrentMigration Error" do
      expect { run_a_migration(:up, 1) }.not_to raise_error
    end

    it "preserves the advisory lock connection when the patch is disabled",
      activerecord_compatibility: "> 7.1" do
      disable_departure_rails_advisory_lock_patch

      establish_mysql_connection

      expect { run_a_migration(:up, 1) }.not_to raise_error
    ensure
      enable_departure_rails_advisory_lock_patch
    end
  end
end
