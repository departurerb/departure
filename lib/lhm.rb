require "lhm/adapter"

# Defines the same global namespace as LHM's gem does to mimic its API
# while providing a different behaviour. We delegate all LHM's methods to
# ActiveRecord so that you don't need to modify your old LHM migrations
module Lhm
  # Yields an adapter instance so that Lhm migration Dsl methods get
  # delegated to ActiveRecord::Migration ones instead
  #
  # @param table_name [String]
  # @param _options [Hash]
  # @param block [Block]
  def self.change_table(table_name, _options = {}, &block) # standard:disable Lint/UnusedMethodArgument
    yield Adapter.new(@migration, table_name)
  end

  # Sets the migration to apply the adapter to
  #
  # @param migration [ActiveRecord::Migration]
  def self.migration=(migration)
    @migration = migration
  end
end
