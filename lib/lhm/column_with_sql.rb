require 'forwardable'

module Lhm
  # Abstracts the details of a table column definition when specified with a MySQL
  # column definition string
  class ColumnWithSql
    extend Forwardable

    # Returns the column's class to be used
    #
    # @return [Constant]
    def self.column_factory
      ::ActiveRecord::ConnectionAdapters::DepartureAdapter::Column
    end

    # Constructor
    #
    # @param name [String, Symbol]
    # @param definition [String]
    def initialize(name, definition)
      @name = name
      @definition = definition
    end

    # Returns the column data as an Array to be used with the splat operator.
    # See Lhm::Adaper#add_column
    #
    # @return [Array]
    def attributes
      [type, column_options]
    end

    private

    def_delegators :column, :limit, :type, :default, :null

    attr_reader :name, :definition

    # TODO: investigate
    #
    # Rails doesn't take into account lenght argument of INT in the
    # definition, as an integer it will default it to 4 not an integer
    #
    # Returns the columns data as a Hash
    #
    # @return [Hash]
    def column_options
      { limit: column.limit, default: column.default, null: column.null }
    end

    # Returns the column instance with the provided data
    #
    # @return [column_factory]
    def column
      cast_type = ActiveRecord::Base.connection.send(:lookup_cast_type, definition)
      metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(
        type: cast_type.type,
        sql_type: definition,
        limit: cast_type.limit
      )
      mysql_metadata = ActiveRecord::ConnectionAdapters::MySQL::TypeMetadata.new(metadata)
      @column ||= self.class.column_factory.new(
        name,
        default_value,
        mysql_metadata,
        null_value
      )
    end

    # Gets the DEFAULT value the column takes as specified in the
    # definition, if any
    #
    # @return [String, NilClass]
    def default_value
      match = if definition =~ /timestamp|datetime/i
                /default '?(.+[^'])'?/i.match(definition)
              else
                /default '?(\w+)'?/i.match(definition)
              end

      return unless match

      match[1].downcase != 'null' ? match[1] : nil
    end

    # Checks whether the column accepts NULL as specified in the definition
    #
    # @return [Boolean]
    def null_value
      match = /((NOT)? NULL)/i.match(definition)
      return true unless match

      match[2]&.downcase == 'not' ? false : true
    end
  end
end
