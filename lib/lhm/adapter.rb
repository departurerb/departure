require 'lhm/column_with_sql'
require 'lhm/column_with_type'

module Lhm
  # Translates Lhm DSL to ActiveRecord's one, so Lhm migrations will now go
  # through Percona as well, without any modification on the migration's
  # code
  class Adapter
    # Constructor
    #
    # @param migration [ActiveRecord::Migtration]
    # @param table_name [String, Symbol]
    def initialize(migration, table_name)
      @migration = migration
      @table_name = table_name
    end

    # Adds the specified column through ActiveRecord
    #
    # @param column_name [String, Symbol]
    # @param definition [String, Symbol]
    def add_column(column_name, definition)
      attributes = column_attributes(column_name, definition)
      migration.add_column(*attributes)
    end

    # Removes the specified column through ActiveRecord
    #
    # @param column_name [String, Symbol]
    def remove_column(column_name)
      migration.remove_column(table_name, column_name)
    end

    # Adds an index in the specified columns through ActiveRecord. Note you
    # can provide a name as well
    #
    # @param columns [Array<String>, Array<Symbol>, String, Symbol]
    # @param index_name [String]
    def add_index(columns, index_name = nil)
      options = { name: index_name } if index_name
      migration.add_index(table_name, columns, options || {})
    end

    # Removes the index in the given columns or by its name
    #
    # @param columns [Array<String>, Array<Symbol>, String, Symbol]
    # @param index_name [String]
    def remove_index(columns, index_name = nil)
      options = if index_name
                  { name: index_name }
                else
                  { column: columns }
                end
      migration.remove_index(table_name, options)
    end

    # Change the column to use the provided definition, through ActiveRecord
    #
    # @param column_name [String, Symbol]
    # @param definition [String, Symbol]
    def change_column(column_name, definition)
      attributes = column_attributes(column_name, definition)
      migration.change_column(*attributes)
    end

    # Renames the old_name column to new_name by using ActiveRecord
    #
    # @param old_name [String, Symbol]
    # @param new_name [String, Symbol]
    def rename_column(old_name, new_name)
      migration.rename_column(table_name, old_name, new_name)
    end

    # Adds a unique index on the given columns, with the provided name if passed
    #
    # @param columns [Array<String>, Array<Symbol>, String, Symbol]
    # @param index_name [String]
    def add_unique_index(columns, index_name = nil)
      options = { unique: true }
      options.merge!(name: index_name) if index_name # rubocop:disable Performance/RedundantMerge

      migration.add_index(table_name, columns, options)
    end

    private

    attr_reader :migration, :table_name

    # Returns the instance of ActiveRecord column with the given name and
    # definition
    #
    # @param name [String, Symbol]
    # @param definition [String]
    def column(name, definition)
      @column ||= if definition.is_a?(Symbol)
                    ColumnWithType.new(name, definition)
                  else
                    ColumnWithSql.new(name, definition)
                  end
    end

    def column_attributes(name, definition)
      attributes = column(name, definition).attributes
      [table_name, name].concat(attributes)
    end
  end
end
