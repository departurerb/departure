# Departure

![Build Status](https://img.shields.io/travis/departurerb/departure?style=for-the-badge) ![Code Climate maintainability](https://img.shields.io/codeclimate/maintainability/departurerb/departure?style=for-the-badge) ![GitHub commits since latest release (by date)](https://img.shields.io/github/commits-since/departurerb/departure/latest/master?style=for-the-badge)

Departure is an **ActiveRecord connection adapter** that allows running
**MySQL online and non-blocking DDL** through `ActiveRecord::Migration` without needing
    to use a different DSL other than Rails' migrations DSL.

It uses `pt-online-schema-change` command-line tool of
[Percona
Toolkit](https://www.percona.com/doc/percona-toolkit/2.0/pt-online-schema-change.html)
which runs MySQL alter table statements without downtime.

## Rename from "Percona Migrator"

This project was formerly known as "Percona Migrator", but this incurs in an
infringement of Percona's trade mark policy and thus has to be renamed. Said
name is likely to cause confusion as to the source of the wrapper.

The next major versions will use "Departure" as gem name.

## Installation

Departure relies on `pt-online-schema-change` from [Percona
Toolkit](https://www.percona.com/doc/percona-toolkit/2.0/pt-online-schema-change.html)

### Mac

`brew install percona-toolkit`

If when running a migration you see an error like:

```
PerconaMigrator::Error: Cannot connect to MySQL: Cannot connect to MySQL because
the Perl DBI module is not installed or not found.
```

You also need to install the DBI and DBD::MySQL modules from `cpan`.

```
$ sudo cpan
cpan> install DBI
cpan> install DBD::mysql
```

### Linux

#### Ubuntu/Debian based

`apt-get install percona-toolkit`

#### Arch Linux

`pacman -S percona-toolkit perl-dbd-mysql`

#### Other distros

For other Linux distributions check out the [Percona Toolkit download
page](https://www.percona.com/downloads/percona-toolkit/) to find the package
that fits your distribution.

You can also get it from [Percona's apt repository](https://www.percona.com/doc/percona-xtradb-cluster/5.5/installation/apt_repo.html)

Once installed, add this line to your application's Gemfile:

```ruby
gem 'departure'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install departure

## Usage

Once you added it to your app's Gemfile, you can create and run Rails migrations
as usual.

All the `ALTER TABLE` statements will be executed with
`pt-online-schema-change`, which will provide additional output to the
migration.

### pt-online-schema-change arguments

#### with environment variable

You can specify any `pt-online-schema-change` arguments when running the
migration. All what you pass in the PERCONA_ARGS env var, will be bypassed to the
binary, overwriting any default values. Note the format is the same as in
`pt-online-schema-change`. Check the full list in [Percona Toolkit
documentation](https://www.percona.com/doc/percona-toolkit/2.2/pt-online-schema-change.html#options)

```ruby
$ PERCONA_ARGS='--chunk-time=1' bundle exec rake db:migrate:up VERSION=xxx
```

or even mulitple arguments

```ruby
$ PERCONA_ARGS='--chunk-time=1 --critical-load Threads_running=55' bundle exec rake db:migrate:up VERSION=xxx
```

Use caution when using PERCONA_ARGS with `db:migrate`, as your args will be applied
to every call that Departure makes to pt-osc.

#### with global configuration

You can specify any `pt-online-schema-change` arguments in global gem configuration
using `global_percona_args` option.

```ruby
Departure.configure do |config|
  config.global_percona_args = '--chunk-time=1 --critical-load Threads_running=55'
end
```

Unlike using `PERCONA_ARGS`, options provided with global configuration will be applied
every time sql command is executed via `pt-online-schema-change`.

Arguments provided in global configuration can be overwritten with `PERCONA_ARGS` env variable.

We recommend using this option with caution and only when you understand the consequences.

### LHM support

If you moved to Soundcloud's [Lhm](https://github.com/soundcloud/lhm) already,
we got you covered. Departure overrides Lhm's DSL so that all the alter
statements also go through `pt-online-schema-change` as well.

You can keep your Lhm migrations and start using Rails migration's DSL back
again in your next migration.

## Configuration

You can override any of the default values from an initializer:

```ruby
Departure.configure do |config|
  config.tmp_path = '/tmp/'
end
```

It's strongly recommended to name it after this gems name, such as
`config/initializers/departure.rb`

### Configuration Options

All configuration options are configurable from the `Departure.configure` block example below

|Option|Default|What it Controls|
|---|---|---|
|disable_rails_advisory_lock_patch|false|When truthy, disables a patch in at least rails 7.1 and 7.2 where rails throws ConcurrentMigrationErrors due to the inability to release the advisory lock in migrations|

### Disable on per-migration basis

Departure gem is enabled by default.
In order to disable it on a particular migration the method `disable_departure!` should be used.

```ruby
class UseDepartureMigration < ActiveRecord::Migration[7.1]
  disable_departure!

  def up
    # ...
  end
  # ...
end
```

### Enable on per-migration basis

If you wish to only have Departure enabled per-migration, set `config.enabled_by_default = false` in the configure block of your departure initializer.

Then, add a `uses_departure!` statement in migrations where Departure should be used:

```ruby
class UseDepartureMigration < ActiveRecord::Migration[7.1]
  uses_departure!

  def up
    # ...
  end
  # ...
end
```

## How it works

When booting your Rails app, Departure extends the
`ActiveRecord::Migration#migrate` method to reset the connection and reestablish
it using the `DepartureAdapter` instead of the one you defined in your
`config/database.yml`.

Then, when any migration DSL methods such as `add_column` or `create_table` are
executed, they all go to the
[DepartureAdapter](https://github.com/departurerb/departure/blob/master/lib/active_record/connection_adapters/departure_adapter.rb).
There, the methods that require `ALTER TABLE` SQL statements, like `add_column`,
are overriden to get executed with
[Departure::Runner](https://github.com/departurerb/departure/blob/master/lib/departure/runner.rb),
which deals with the `pt-online-schema-change` binary. All the others, like
`create_table`, are delegated to the ActiveRecord's built in Mysql2Adapter and
so they follow the regular path.

[Departure::Runner](https://github.com/departurerb/departure/blob/master/lib/departure/runner.rb)
spawns a new process that runs the `pt-online-schema-change` binary present in
the system, with the appropriate arguments for the generated SQL.

When any errors occur, an `ActiveRecord::StatementInvalid` exception is
raised and the migration is aborted, as all other ActiveRecord connection
adapters.

## Trouleshooting

### Error creating new table: DBD::mysql::db do failed: Can't write; duplicate key in table (TABLE_NAME)
There is a [known bug](https://bugs.launchpad.net/percona-toolkit/+bug/1498128) in percona-toolkit version 2.2.15
that prevents schema changes when a table has constraints. You should upgrade to a version later than 2.2.17 to fix the issue.

## Development

### Setup

#### Docker Compose

You can bring up the docker-compose setup and bash into rails in order to not install dependencies on your system

```
docker compose up
docker compose exec rails bash
bundle install
# off to the races
```

#### Manual

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

### Appraisal

All versions of supported rails are defined in the Appraisal file

#### Usage

Say you want to run a specific test under a version of rails defined in Appraisal `rails-8-0`

```
bundle exec appraisal rails-8-0 bundle install
bundle exec appraisal rails-8-0 bundle exec rspec spec/lhm/column_with_sql_spec.rb:50
```

#### Adding Versions

 - Add the version to Appraisal
 - Run `bundle exec appraisal generate`
 - Run `bundle exec appraisal install`
 - updates test.yml in the `gemfile:` section

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/departurerb/departure.

Please note that this project is released with a Contributor Code of Conduct. By
participating in this project you agree to abide by its terms.

Check the code of conduct [here](CODE_OF_CONDUCT.md)

## Changelog

You can consult the changelog [here](CHANGELOG.md)

## License

The gem is available as open source under the terms of the [MIT
License](http://opensource.org/licenses/MIT).

![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/departurerb/departure?style=for-the-badge)
![GitHub issues](https://img.shields.io/github/issues/departurerb/departure?style=for-the-badge)
