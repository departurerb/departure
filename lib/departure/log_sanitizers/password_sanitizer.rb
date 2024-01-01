module Departure
  module LogSanitizers
    class PasswordSanitizer
      PASSWORD_REPLACEMENT = '[filtered_password]'.freeze

      delegate :password_argument, to: :connection_details

      def initialize(connection_details)
        @connection_details = connection_details
      end

      def execute(log_statement)
        return log_statement if password_argument.blank?

        log_statement.gsub(password_argument, PASSWORD_REPLACEMENT)
      end

      private

      attr_accessor :connection_details
    end
  end
end
