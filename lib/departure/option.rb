module Departure
  class Option
    attr_reader :name, :value

    # Builds an instance by parsing its name and value out of the given string.
    #
    # @param string [String]
    # @return [Option]
    def self.from_string(string)
      name, value = string.split(/\s|=/, 2)
      new(name, value)
    end

    # Constructor
    #
    # @param name [String]
    # @param optional value [String]
    def initialize(name, value = nil)
      @name = normalize_option(name)
      @value = value
    end

    # Compares two options
    #
    # @param [Option]
    # @return [Boolean]
    def ==(other)
      name == other.name
    end
    alias_method :eql?, :==

    # Returns the option's hash
    #
    # @return [Fixnum]
    def hash
      name.hash
    end

    # Returns the option as string following the "--<name>=<value>" format or
    # the short "-n=value" format
    #
    # @return [String]
    def to_s
      "#{name}#{value_as_string}"
    end

    private

    # Returns the option name in "long" format, e.g., "--name"
    #
    # @return [String]
    def normalize_option(name)
      if name.start_with?("-")
        name
      elsif name.length == 1
        "-#{name}"
      else
        "--#{name}"
      end
    end

    # Returns the value fragment of the option string if any value is specified
    #
    # @return [String]
    def value_as_string
      if value.nil?
        ""
      elsif value.include?("=")
        " #{value}"
      else
        "=#{value}"
      end
    end
  end
end
