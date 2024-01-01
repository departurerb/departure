module Departure
  # Copies the ActiveRecord::Migration #say and #write plus a new
  # #write_no_newline to log the migration's status. It's not possible to reuse
  # the from ActiveRecord::Migration because the migration's instance can't be
  # seen from the connection adapter.
  class Logger
    def initialize(sanitizers)
      @sanitizers = sanitizers
    end

    # Outputs the message through the stdout, following the
    # ActiveRecord::Migration log format
    #
    # @param message [String]
    # @param subitem [Boolean] whether to show message as a nested log item
    def say(message, subitem: false)
      write "#{subitem ? '   ->' : '--'} #{message}"
    end

    # Outputs the text through the stdout adding a new line at the end
    #
    # @param text [String]
    def write(text = '')
      puts(sanitize(text))
    end

    # Outputs the text through the stdout without adding a new line at the end
    #
    # @param text [String]
    def write_no_newline(text)
      print(sanitize(text))
    end

    private

    attr_accessor :sanitizers

    def sanitize(text)
      sanitizers.inject(text) { |memo, sanitizer| sanitizer.execute(memo) }
    end
  end
end
