module Departure
  module RailsPatches
    module ActiveRecordMigratorWithAdvisoryLockPatch
      RELEASE_LOCK_FAILED_MESSAGE = 'Failed to release advisory lock from ActiveRecordMigratorWithAdvisoryLockPatch'
                                      .freeze

      def with_advisory_lock
        return super if Departure.configuration.disable_rails_advisory_lock_patch

        lock_id = generate_migrator_advisory_lock_id
        @__original_connection = connection

        got_lock = @__original_connection.get_advisory_lock(lock_id)
        raise ActiveRecord::ConcurrentMigrationError unless got_lock

        load_migrated # reload schema_migrations to be sure it wasn't changed by another process before we got the lock
        yield
      ensure
        if got_lock && !@__original_connection.release_advisory_lock(lock_id)
          raise ActiveRecord::ConcurrentMigrationError, RELEASE_LOCK_FAILED_MESSAGE
        end
      end
    end
  end
end
