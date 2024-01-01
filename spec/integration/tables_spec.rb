require 'spec_helper'

describe Departure, integration: true do
  let(:migration_paths) { [MIGRATION_FIXTURES] }
  let(:direction) { :up }

  context 'creating a table' do
    let(:version) { 8 }

    it 'creates the table' do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
      expect(tables).to include('things')
    end

    it 'marks the migration as up' do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
      expect(ActiveRecord::Migrator.current_version).to eq(version)
    end
  end

  context 'dropping a table' do
    let(:version) { 8 }
    let(:direction) { :down }

    it 'drops the table' do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
      expect(tables).not_to include('things')
    end

    it 'updates the schema_migrations' do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
      expect(ActiveRecord::Migrator.current_version).to eq(0)
    end
  end

  context 'renaming a table' do
    let(:version) { 24 }

    before do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, 1)
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, 2)
    end

    it 'changes the table name' do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
      expect(tables).to include('new_comments')
    end

    it 'does not keep the old name' do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
      expect(tables).not_to include('comments')
    end

    it 'changes the index names in the new table' do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
      expect(:new_comments).to have_index('index_new_comments_on_some_id_field')
    end
  end
end
