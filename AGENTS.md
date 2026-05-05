# Context

Departure is a Ruby gem that wraps Rails ActiveRecord migrations using `ALTER TABLE` statements with `pt-online-schema-change` (Percona Toolkit) so DDL runs online and non-blocking.

It must stay aware of how the ActiveRecord API changes across versions and supports all currently supported versions of Rails and Ruby.

It supports both the `mysql2` and `trilogy` database adapter gems (trilogy on Rails 8.1+).

# Project Layout

- `lib/active_record/connection_adapters/` — per-Rails-version connection adapters:
  - `rails_7_2_departure_adapter.rb`
  - `rails_8_0_departure_adapter.rb`
  - `rails_8_1_mysql2_adapter.rb`
  - `rails_8_1_trilogy_adapter.rb`
  - `for_alter.rb`, `patch_connection_handling.rb` — shared behavior
- `lib/departure/rails_adapter.rb` — version dispatch. `Departure::RailsAdapter.for(ar_version, db_connection_adapter:)` selects the right adapter class. New Rails/adapter combinations are wired in here.
- `lib/departure/railtie.rb` — Rails integration entry point; calls `RailsAdapter.register_integrations`.
- `lib/departure/runner.rb`, `cli_generator.rb`, `command.rb` — intercept ALTER statements and shell out to `pt-online-schema-change`.
- `lib/departure/rails_patches/` — targeted patches against ActiveRecord internals.
- `lib/lhm/` — LHM DSL compatibility shim.
- `spec/dummy/` — minimal Rails app used by integration specs.

# Adapter Selection

1. If the database config specifies `trilogy` (Rails 8.1+), use the trilogy adapter.
2. Otherwise default to `mysql2`.

Selection lives in `Departure::RailsAdapter.for`. When adding a new Rails version, add a `V<MAJOR>_<MINOR>_*Adapter` subclass of `BaseAdapter` and update the dispatch logic.

# Development

- `docker-compose.yml` brings up a MySQL database container and a Rails container with the gem mounted in.
- The `Appraisal` gem manages Rails version dependencies; configurations live in `Appraisals` and generated gemfiles in `gemfiles/`.
- Local gems are vendored to `tmp/local_gems` (mounted at `/app/vendor/bundle`) so debugging tools like `pry` can step through ActiveRecord internals.

## Required env vars
Set by `docker-compose.yml`; if running outside Docker, export them yourself:

- `PERCONA_DB_USER`
- `PERCONA_DB_PASSWORD`
- `PERCONA_DB_HOST`
- `PERCONA_DB_NAME`
- `DB_ADAPTER=trilogy` — only when running against trilogy (Rails 8.1)

## External dependencies

- `pt-online-schema-change` from Percona Toolkit must be on `PATH` — the gem shells out to it. CI installs it from the Percona APT repo.
- MySQL server. Trilogy requires `mysql_native_password` auth, not `caching_sha2_password`. CI runs `ALTER USER ... IDENTIFIED WITH mysql_native_password` followed by `FLUSH PRIVILEGES` before the trilogy job.

# Testing

- Be sure that changes are valid against both `rubocop` and the `rspec` suites.
- The supported test matrix is defined in `.github/workflows/test.yml`:
  - **mysql2:** Ruby 3.2 / 3.3 / 3.4 × Rails 7.2 / 8.0 / 8.1
  - **trilogy:** Ruby 3.2 / 3.3 / 3.4 × Rails 8.1 only
  - **lint:** Ruby 3.4 with the Rails 8.1 gemfile
- Run inside Docker via `appraisal`:
  - Full suite: `docker compose exec rails bundle exec appraisal rails-8-1 bundle exec rspec spec`
  - Single example: `docker compose exec rails bundle exec appraisal rails-8-1 bundle exec rspec spec/path/to_spec.rb:LINE`
  - Trilogy run: prepend `DB_ADAPTER=trilogy` to the rspec command (rails-8-1 only)
  - Lint: `docker compose exec rails bundle exec appraisal rails-8-1 bundle exec rubocop --parallel`

# Adding a Rails version

1. Add an `appraise '<rails-x-y>' do ... end` block in `Appraisals`.
2. `bundle exec appraisal generate && bundle exec appraisal install`
3. Add a matching `V<X>_<Y>_*Adapter` class in `lib/departure/rails_adapter.rb` and a connection-adapter file under `lib/active_record/connection_adapters/`.
4. Update the `gemfile:` matrix in `.github/workflows/test.yml`. Add a separate `test_trilogy` entry only if trilogy is supported on that version.

# Conventions

- Follow the existing adapter naming pattern: `rails_<MAJOR>_<MINOR>_<DRIVER>_adapter.rb` and register through `Departure::RailsAdapter`. Don't introduce a parallel registration path.
- User-visible changes go in `CHANGELOG.md` (Keep a Changelog format).
- Release process is documented in `RELEASING.md`.
