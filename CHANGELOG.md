# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

Please follow the format in [Keep a Changelog](http://keepachangelog.com/)

## [Unreleased]

- Drop Ruby 3.0 support in specs
- Create dummy application in specs, migrate fixtures to that application
- Create a `bin/rails` command that loads the database from the dummy application

## [6.7.0] - 2024-02-20

- Flex mysql2 dependency to < 0.6 and bump version to 0.5.6
- Drop support for older than the latest EOL Ruby (2.7) and Rails (6.0)

## [6.6.0] - 2024-01-02

- Fix support for Rails 6.0 and ForAlter `remove_index` .
- Support Rails 7.1.2

## [6.5.0] - 2023-01-24

- Support mysql gem version 0.5.5
- Support for connection to MySQL server over socket
- Support appending items to the general DSN. Used to apply workaround for [PT-2126](https://jira.percona.com/browse/PT-2126)

## [6.4.0] - 2022-08-24

- Support for ActiveRecord 6.1.4
- Relax mysql2 requirement to allow mysql2 0.5.4
- Support Rails 6' #upsert_all

## [6.3.0] - 2020-06-23

- Support for ActiveRecord 6.1

## [6.2.0] - 2020-06-23

### Added

- Support for ActiveRecord 6.0
- Support for ActiveRecord 5.2
- Relax mysql2 requirement to allow mysql2 0.5.3
- Support to batch multiple changes at once with #change_table
- Support for connection to MySQL server over SSL

### Changed

- Depend only in railties and activerecord instead of rails gem

### Deprecated
### Removed
### Fixed

- Fix support for removing foreign keys
- Fix PERCONA_ARGS syntax for critical-load option
- Make sure quotes in ALTER TABLE get correctly escaped
- Fixes for regex handling
- Fix LHM compatibility

## [6.1.0] - 2018-02-27

### Added
### Changed

- Permit PERCONA_ARGS to be applied to db:migrate tasks

### Deprecated
### Removed
### Fixed

- Output lines are no longer wrapped at 8 chars

## [6.0.0] - 2017-09-25

### Added

- Support for ActiveRecord 5.1

### Changed
### Deprecated
### Removed
### Fixed

## [5.0.0] - 2017-09-19

### Added

- Support for ActiveRecord 5.0
- Docker setup to run the spec suite

### Changed
### Deprecated
### Removed
### Fixed

- Allow using bash special characters in passwords

## [4.0.1] - 2017-08-01

### Added

- Support for all pt-osc command-line options, including short forms and array
    arguments

### Changed
### Deprecated
### Removed
### Fixed

## [4.0.0] - 2017-06-12

### Added
### Changed

- Rename the gem from percona_migrator to departure.

### Deprecated
### Removed

- Percona_migrator's deprecation warnings when installing and running the gem.

### Fixed

## [3.0.0] - 2016-04-07

### Added

- Support for ActiveRecord 4.2.x
- Support for Mysql2 4.x
- Allow passing any `pt-online-schema-change`'s arguments through the
   `PERCONA_ARGS` env var when executing a migration with `rake db:migrate:up`
   or `db:migrate:down`.
- Allow setting global percona arguments via gem configuration
- Filter MySQL's password from logs

### Changed

- Enable default pt-online-schema-change replicas discovering mechanism.
    So far, this was purposely set to `none`. To keep this same behaviour
    provide the `PERCONA_ARGS=--recursion-method=none` env var when running the
    migration.

## [1.0.0] - 2016-11-30

### Added

- Show pt-online-schema-change's stdout while the migration is running instead
    of at then and all at once.
- Store pt-online-schema-change's stderr to percona_migrator_error.log in the
    default Rails tmp folder.
- Allow configuring the tmp directory where the error log gets written into,
    with the `tmp_path` configuration setting.
- Support for ActiveRecord 4.0. Adds the following migration methods:
  - #rename_index, #change_column_null, #add_reference, #remove_reference,
    #set_field_encoding, #add_timestamps, #remove_timestamps, #rename_table,
    #rename_column

## [0.1.0.rc.7] - 2016-09-15

### Added

- Toggle pt-online-schema-change's output as well when toggling the migration's
    verbose option.

### Changed

- Enabled pt-online-schema-change's output while running the migration, that got
  broken in v0.1.0.rc.2

## [0.1.0.rc.6] - 2016-04-07

### Added

- Support non-ddl migrations by implementing the methods for the ActiveRecord
    quering to work.

### Changed

- Refactor the PerconaAdapter to use the Runner as connection client, as all the
    other adapters.

## [0.1.0.rc.5] - 2016-03-29

### Changed

- Raise a ActiveRecord::StatementInvalid on failed migration. It also provides
    more detailed error message when possible such as pt-onlin-schema-change
    being missing.

## [0.1.0.rc.4] - 2016-03-15

### Added

- Support #drop_table
- Support for foreing keys in db/schema.rb when using [Foreigner
gem](https://github.com/matthuhiggins/foreigner) in Rails 3 apps. This allows to
define foreign keys with #execute, but does not provide support for
add_foreign_key yet.

## [0.1.0.rc.3] - 2016-03-10

### Added

- Support #execute. Allows to execute raw SQL from the migration

## [0.1.0.rc.2] - 2016-03-09

### Added

- VERBOSE env var in tests. Specially useful for integration tests.
- Fix #create_table migration method. Now it does create the table.

### Changed

- Use ActiveRecord's logger instead of specifying one in the connection data.

## [0.1.0.rc.1] - 2016-03-01

- Initial gem version
