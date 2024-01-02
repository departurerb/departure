require 'spec_helper'

describe Departure, integration: true do
  class Comment < ActiveRecord::Base; end

  let(:migration_context) do
    ActiveRecord::MigrationContext.new([MIGRATION_FIXTURES], ActiveRecord::SchemaMigration)
  end

  let(:direction) { :up }

  context 'managing columns' do
    let(:version) { 1 }

    context 'creating column' do
      let(:direction) { :up }

      it 'adds the column in the DB table' do
        migration_context.run(direction, version)

        expect(:comments).to have_column('some_id_field')
      end

      it 'marks the migration as up' do
        migration_context.run(direction, version)

        expect(migration_context.current_version).to eq(version)
      end
    end

    context 'dropping column' do
      let(:direction) { :down }

      before do
        migration_context.up(version)
      end

      it 'drops the column from the DB table' do
        migration_context.run(direction, version)

        expect(:comments).not_to have_column('some_id_field')
      end

      it 'marks the migration as down' do
        migration_context.run(direction, version)

        expect(migration_context.current_version).to eq(version - 1)
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
        migration_context.run(direction, version)
        expect(:comments).to have_column('new_id_field')
      end

      it 'does not keep the old column' do
        migration_context.run(direction, version)
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
      migration_context.up(1)
    end

    context 'when null is true' do
      let(:version) { 14 }

      it 'sets the column to allow nulls' do
        migration_context.run(direction, version)
        expect(column.null).to be_truthy
      end

      it 'marks the migration as up' do
        migration_context.run(direction, version)
        expect(migration_context.current_version).to eq(version)
      end
    end

    context 'when null is false' do
      let(:version) { 15 }

      it 'sets the column not to allow nulls' do
        migration_context.run(direction, version)
        expect(column.null).to be_falsey
      end

      it 'marks the migration as up' do
        migration_context.run(direction, version)
        expect(migration_context.current_version).to eq(version)
      end
    end
  end

  context 'adding timestamps' do
    let(:version) { 22 }

    it 'adds a created_at column' do
      migration_context.run(direction, version)
      expect(:comments).to have_column('created_at')
    end

    it 'adds a updated_at column' do
      migration_context.run(direction, version)
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
      migration_context.run(direction, version)
      expect(:comments).not_to have_column('created_at')
    end

    it 'removes the updated_at column' do
      migration_context.run(direction, version)
      expect(:comments).not_to have_column('updated_at')
    end
  end
end
