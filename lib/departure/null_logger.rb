module Departure
  class NullLogger
    def say(_message, _subitem: false)
      # noop
    end

    def write(_text)
      # noop
    end

    def write_no_newline(_text)
      # noop
    end
  end
end
