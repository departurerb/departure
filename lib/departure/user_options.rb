module Departure
  # Encapsulates the pt-online-schema-change options defined by the user
  class UserOptions
    delegate :each, :merge, to: :to_set

    # Constructor
    #
    # @param arguments [String]
    def initialize(arguments = ENV.fetch('PERCONA_ARGS', nil))
      @arguments = arguments
    end

    private

    attr_reader :arguments

    # Returns the arguments the user defined but without duplicates
    #
    # @return [Set]
    def to_set
      Set.new(user_options)
    end

    # Returns Option instances from the arguments the user specified, if any
    #
    # @return [Array]
    def user_options
      if arguments
        build_options
      else
        []
      end
    end

    # Builds Option instances from the user arguments
    #
    # @return [Array<Option>]
    def build_options
      arguments.split(/\s(?=-)/).map do |argument|
        Option.from_string(argument)
      end
    end
  end
end
