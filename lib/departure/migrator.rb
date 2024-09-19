module Departure
  module Migrator
    extend ActiveSupport::Concern

    included do
      private

      def with_advisory_lock
        lock_id = generate_migrator_advisory_lock_id

        with_advisory_lock_connection do |connection|
          got_lock = connection.get_advisory_lock(lock_id)
          raise ConcurrentMigrationError unless got_lock
          load_migrated # reload schema_migrations to be sure it wasn't changed by another process before we got the lock
          yield
        ensure
          if got_lock && !connection.release_advisory_lock(lock_id)
            raise ConcurrentMigrationError.new(
              ConcurrentMigrationError::RELEASE_LOCK_FAILED_MESSAGE
            )
          end
        end
      end

      def with_advisory_lock_connection(&block)
        pool = ActiveRecord::ConnectionAdapters::ConnectionHandler.new.establish_connection(
          ActiveRecord::Base.connection_db_config
        )

        pool.with_connection(&block)
      ensure
        pool&.disconnect!
      end
    end
  end
end
