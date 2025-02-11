require 'forwardable'

module Departure
  module AdapterExtensions
    module Mysql2
      extend Forwardable

      def_delegators :mysql_adapter, :each_hash, :set_field_encoding

      def internal_exec_query(sql, name = 'SQL', _binds = [], **_kwargs) # :nodoc:
        result = execute(sql, name)
        fields = result.fields if defined?(result.fields)
        ActiveRecord::Result.new(fields, result.to_a)
      end
      alias exec_query internal_exec_query

      # This is a method defined in Rails 6.0, and we have no control over the
      # naming of this method.
      def get_full_version # rubocop:disable Style/AccessorMethodName
        mysql_adapter.raw_connection.server_info[:version]
      end

      def last_inserted_id(result)
        mysql_adapter.send(:last_inserted_id, result)
      end
    end
  end
end
