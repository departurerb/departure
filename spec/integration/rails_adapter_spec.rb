require 'spec_helper'

RSpec.describe Departure::RailsAdapter, integration: true do
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
