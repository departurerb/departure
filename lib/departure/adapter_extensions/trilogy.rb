require 'forwardable'

module Departure
  module AdapterExtensions
    module Trilogy
      extend Forwardable

      def_delegators :mysql_adapter,
                     :exec_query,
                     :select_all,
                     :set_field_encoding

      alias internal_exec_query exec_query

      # This is a method defined in Rails 6.0, and we have no control over the
      # naming of this method.
      def get_full_version # rubocop:disable Style/AccessorMethodName
        mysql_adapter.connect! if mysql_adapter.raw_connection.nil?
        mysql_adapter.raw_connection.server_info[:version]
      end

      def last_inserted_id(_result)
        mysql_adapter.raw_connection.last_insert_id
      end

      private

      # Not forwarding this method via 'def_delegators' to avoid the following warning:
      # warning: ActiveRecord::ConnectionAdapters::DepartureAdapter#each_hash
      #          at /usr/local/lib/ruby/<version>/forwardable.rb:157
      #          forwarding to private method ActiveRecord::ConnectionAdapters::TrilogyAdapter#each_hash
      # Defining the method and calling the private method of the adapter instead
      def each_hash(result, &block) # :nodoc:
        if block_given?
          mysql_adapter.send(:each_hash, result, &block)
        else
          mysql_adapter.send(:each_hash, result)
        end
      end
    end
  end
end
