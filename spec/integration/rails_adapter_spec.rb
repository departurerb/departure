require 'spec_helper'

RSpec.describe Departure::RailsAdapter, integration: true do
  describe "advisory_lock patch" do
    before(:each) do
      # We have to force a reconnection in order to get a migration error when we switch adapters
      establish_mysql_connection
    end

    def run_a_migration
      migration_context = ActiveRecord::MigrationContext.new([MIGRATION_FIXTURES], ActiveRecord::SchemaMigration)
      migration_context.run(:up, 1)
    end

    it "runs migrations without throwing an ActiveRecord::ConcurrentMigration Error" do
      establish_mysql_connection

      expect { run_a_migration }.not_to raise_error
    end

    it "throws an exception when we are in rails 7.1 and have the patch disabled", activerecord_compatibility: "> 7.1" do
      Departure.configure do |config|
        config.disable_rails_advisory_lock_patch = true
      end

      establish_mysql_connection

      expect { run_a_migration }.to raise_error(ActiveRecord::ConcurrentMigrationError)
    end
  end
end


