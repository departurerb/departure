require 'spec_helper'

describe Departure, integration: true do
  let(:migration_fixtures) do
    File.expand_path('../fixtures/lhm_migrate/', __FILE__)
  end
  let(:direction) { :up }

  context 'creating/removing columns' do
    let(:version) { 1 }

    context 'creating column' do
      let(:direction) { :up }

      xit 'adds the column in the DB table' do
        ActiveRecord::Migrator.new(
          direction,
          [migration_fixtures],
          ActiveRecord::SchemaMigration,
          version
        ).migrate

        Comment.reset_column_information
        expect(Comment.column_names).to include('some_id_field')
      end
    end
  end
end
