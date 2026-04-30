require 'spec_helper'

describe Departure, integration: true do
  let(:migration_paths) { [MIGRATION_FIXTURES] }
  let(:direction) { :up }

  context 'creating references' do
    context 'when no option is set' do
      let(:version) { 16 }

      it 'adds a reference column' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(:comments).to have_column('user_id')
      end
    end

    context 'when polymorphic is set to true' do
      let(:version) { 17 }

      it 'adds a column for the id' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(:comments).to have_column('user_id')
      end

      it 'adds a column for the type' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(:comments).to have_column('user_type')
      end

      context 'and index is set to true' do
        let(:version) { 19 }

        it 'adds a compound index for both the id and type columns' do
          ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
          expect(:comments)
            .to have_index('index_comments_on_user_type_and_user_id')
        end
      end
    end

    context 'when index is set to true' do
      let(:version) { 18 }

      it 'adds an index for the reference column' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)

        expect(:comments).to have_index('index_comments_on_user_id')
      end
    end
  end

  context 'removing references' do
    let(:version) { 20 }

    before { ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, 16) }

    context 'when no option is set' do
      it 'removes the reference column' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(:comments).not_to have_column('user_id')
      end
    end

    context 'when polymorphic is set to true' do
      it 'removes the reference id column' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(:comments).not_to have_column('user_id')
      end

      it 'removes the reference type column' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(:comments).not_to have_column('user_type')
      end
    end
  end
end
