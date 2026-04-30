require 'spec_helper'
require 'active_record/tasks/database_tasks'
require 'tmpdir'

describe Departure, 'multiple databases', integration: true, activerecord_compatibility: RAILS_8_1 do
  attr_reader :db_dir, :original_configurations, :original_db_dir, :primary_migrations_path,
              :secondary_migrations_path

  let(:commands) { [] }
  let(:command) { instance_double(Departure::Command, run: status) }
  let(:status) { instance_double(Process::Status) }

  before do
    @original_configurations = ActiveRecord::Base.configurations
    @original_db_dir = ActiveRecord::Tasks::DatabaseTasks.instance_variable_get(:@db_dir)
    @db_dir = Dir.mktmpdir('departure-db')
    @primary_migrations_path = Dir.mktmpdir('departure-primary-migrations')
    @secondary_migrations_path = Dir.mktmpdir('departure-secondary-migrations')
    ActiveRecord::Tasks::DatabaseTasks.db_dir = db_dir

    reset_database(primary_database)
    reset_database(secondary_database)
    write_migration(
      primary_migrations_path,
      '20260101000000_add_index_to_primary_comments.rb',
      'AddIndexToPrimaryComments'
    )
    write_migration(
      secondary_migrations_path,
      '20260101000001_add_index_to_secondary_comments.rb',
      'AddIndexToSecondaryComments'
    )
    use_multiple_database_configuration

    allow(Departure::Command).to receive(:new) do |command_line, *|
      commands << command_line
      command
    end
  end

  after do
    ActiveRecord::Base.configurations = original_configurations
    ActiveRecord::Tasks::DatabaseTasks.db_dir = original_db_dir
    establish_mysql_connection

    drop_database(primary_database)
    drop_database(secondary_database)
    FileUtils.remove_entry(db_dir) if db_dir
    FileUtils.remove_entry(primary_migrations_path) if primary_migrations_path
    FileUtils.remove_entry(secondary_migrations_path) if secondary_migrations_path
  end

  it 'migrates every configured database' do
    ActiveRecord::Tasks::DatabaseTasks.migrate_all

    expect(primary_schema_versions).to include('20260101000000')
    expect(secondary_schema_versions).to include('20260101000001')
    expect(commands).to contain_exactly(
      a_string_including("D=#{primary_database},t=comments"),
      a_string_including("D=#{secondary_database},t=comments")
    )
  end

  def primary_config
    database_config(name: 'primary', database: primary_database, migrations_path: primary_migrations_path)
  end

  def secondary_config
    database_config(
      name: 'secondary',
      database: secondary_database,
      migrations_path: secondary_migrations_path
    )
  end

  def primary_database
    'departure_primary_test'
  end

  def secondary_database
    'departure_secondary_test'
  end

  def database_config(name:, database:, migrations_path:)
    ActiveRecord::DatabaseConfigurations::HashConfig.new(
      ActiveRecord::Tasks::DatabaseTasks.env,
      name,
      db_config_for(
        adapter: 'mysql2',
        database: database,
        migrations_paths: migrations_path
      )
    )
  end

  def use_multiple_database_configuration
    ActiveRecord::Base.configurations = ActiveRecord::DatabaseConfigurations.new(
      [
        primary_config,
        secondary_config
      ]
    )
  end

  def reset_database(database)
    drop_database(database)

    ActiveRecord::Base.connection.execute(
      "CREATE DATABASE #{quote_table_name(database)} DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci"
    )
    ActiveRecord::Base.connection.execute(
      "CREATE TABLE #{quote_table_name(database)}.comments " \
      '(id bigint(20) NOT NULL AUTO_INCREMENT, some_id_field int(11), PRIMARY KEY (id)) ' \
      'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci'
    )
  end

  def drop_database(database)
    ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS #{quote_table_name(database)}")
  end

  def quote_table_name(name)
    ActiveRecord::Base.connection.quote_table_name(name)
  end

  def write_migration(path, file_name, class_name)
    File.write(
      File.join(path, file_name),
      [
        "class #{class_name} < ActiveRecord::Migration[8.1]",
        '  def change',
        '    add_index :comments, :some_id_field',
        '  end',
        'end'
      ].join("\n")
    )
  end

  def primary_schema_versions
    schema_versions_for(primary_database)
  end

  def secondary_schema_versions
    schema_versions_for(secondary_database)
  end

  def schema_versions_for(database)
    ActiveRecord::Base.connection.select_values(
      "SELECT version FROM #{quote_table_name(database)}.schema_migrations"
    )
  rescue ActiveRecord::StatementInvalid
    []
  end
end
