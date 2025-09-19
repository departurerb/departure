require 'departure'
require 'lhm' # It's our own Lhm adapter, not the gem
require 'rails'

module Departure
  class Railtie < Rails::Railtie
    railtie_name :departure

    initializer 'departure.configure' do |app|
      Departure.configure do |config|
        config.tmp_path = app.paths['tmp'].first
      end
    end

    config.after_initialize do
      Departure.configure do |dc|
        ActiveRecord::Migration.uses_departure = dc.enabled_by_default
      end

      Departure::RailsAdapter.for_current(ApplicationRecord.connection.config)
    end
  end
end
