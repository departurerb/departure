require 'spec_helper'

describe Departure, integration: true do
  let(:migration_fixtures) do
    ActiveRecord::MigrationContext.new([MIGRATION_FIXTURES], ActiveRecord::SchemaMigration).migrations
  end
  let(:migration_paths) { [MIGRATION_FIXTURES] }

  let(:direction) { :up }

  context 'managing columns' do
    let(:version) { 1 }

    context 'creating column' do
      let(:direction) { :up }

      it 'adds the column in the DB table' do
        ActiveRecord::Migrator.new(
          direction,
          migration_fixtures,
          ActiveRecord::SchemaMigration,
          version
        ).migrate

        expect(:comments).to have_column('some_id_field')
      end

      it 'marks the migration as up' do
        ActiveRecord::Migrator.new(
          direction,
          migration_fixtures,
          ActiveRecord::SchemaMigration,
          version
        ).migrate

        expect(ActiveRecord::Migrator.current_version).to eq(version)
      end
    end

    context 'dropping column' do
      let(:direction) { :down }

      before do
        ActiveRecord::Migrator.new(:up, migration_fixtures, ActiveRecord::SchemaMigration, version).migrate
      end

      it 'drops the column from the DB table' do
        ActiveRecord::Migrator.new(
          direction,
          migration_fixtures,
          ActiveRecord::SchemaMigration,
          version - 1
        ).migrate

        expect(:comments).not_to have_column('some_id_field')
      end

      it 'marks the migration as down' do
        ActiveRecord::Migrator.new(
          direction,
          migration_fixtures,
          ActiveRecord::SchemaMigration,
          version - 1
        ).migrate

        expect(ActiveRecord::Migrator.current_version).to eq(version - 1)
      end
    end

    context 'renaming column' do
      let(:version) { 25 }

      before do
        ActiveRecord::Base.connection.add_column(
          :comments,
          :some_id_field,
          :integer,
          limit: 8, default: nil
        )
      end

      it 'changes the column name' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(:comments).to have_column('new_id_field')
      end

      it 'does not keep the old column' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(:comments).not_to have_column('some_id_field')
      end
    end
  end

  context 'when changing column null' do
    let(:direction) { :up }
    let(:column) do
      columns(:comments).find { |column| column.name == 'some_id_field' }
    end

    before do
      ActiveRecord::Migrator.new(:up, migration_fixtures, ActiveRecord::SchemaMigration, 1).migrate
    end

    context 'when null is true' do
      let(:version) { 14 }

      it 'sets the column to allow nulls' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(column.null).to be_truthy
      end

      it 'marks the migration as up' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(ActiveRecord::Migrator.current_version).to eq(version)
      end
    end

    context 'when null is false' do
      let(:version) { 15 }

      it 'sets the column not to allow nulls' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(column.null).to be_falsey
      end

      it 'marks the migration as up' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(ActiveRecord::Migrator.current_version).to eq(version)
      end
    end
  end

  context 'adding timestamps' do
    let(:version) { 22 }

    it 'adds a created_at column' do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
      expect(:comments).to have_column('created_at')
    end

    it 'adds a updated_at column' do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
      expect(:comments).to have_column('updated_at')
    end
  end

  context 'removing timestamps' do
    let(:version) { 23 }

    before do
      ActiveRecord::Base.connection.add_timestamps(
        :comments,
        null: true,
        default: nil
      )
    end

    it 'removes the created_at column' do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
      expect(:comments).not_to have_column('created_at')
    end

    it 'removes the updated_at column' do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
      expect(:comments).not_to have_column('updated_at')
    end
  end
end
