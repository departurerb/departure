require "spec_helper"
require "open3"

# Boots the dummy app in a separate process with the other database driver
# hidden, as if the app didn't have it installed, and runs a migration through
# Departure. Guards against Departure loading a driver the app doesn't use.
describe "Booting with a single database driver", integration: true do
  let(:driver) { ENV.fetch("DB_ADAPTER", "mysql2") }
  let(:other_driver) { (%w[mysql2 trilogy] - [driver]).first }

  let(:script) do
    <<~'RUBY'
      require "bundler/setup"

      blocked = ENV.fetch("BLOCKED_DRIVER")
      $LOAD_PATH.reject! { |path| path.split("/").any? { |dir| dir.start_with?("#{blocked}-") } }

      require "./spec/dummy/config/environment"

      ActiveRecord::MigrationContext.new(["spec/dummy/db/migrate"]).run(:up, 1)

      drivers = $LOADED_FEATURES.grep(%r{/(mysql2|trilogy)\.rb\z}).map { |path| File.basename(path, ".rb") }
      puts "loaded drivers: #{drivers.uniq.sort.join(",")}"
    RUBY
  end

  def boot_dummy_app
    env = {"DB_ADAPTER" => driver, "BLOCKED_DRIVER" => other_driver}
    Open3.capture2e(env, RbConfig.ruby, "-e", script, chdir: File.expand_path("../..", __dir__))
  end

  it "boots and runs migrations without loading the other driver" do
    output, status = boot_dummy_app

    expect(status).to be_success, output
    expect(output).to include("loaded drivers: #{driver}\n")
    expect(:comments).to have_column("some_id_field")
  end
end
