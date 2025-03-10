# frozen_string_literal: true

# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

run Rails.application

if Rails.application.respond_to? :load_server
  Rails.application.load_server
end
