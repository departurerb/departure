# frozen_string_literal: true

require_relative 'boot'

require 'active_record/railtie'

Bundler.require(*Rails.groups)
require 'departure'

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
  end
end
