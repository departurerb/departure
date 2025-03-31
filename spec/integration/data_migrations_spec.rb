require 'spec_helper'

describe Departure, integration: true do
  class Comment < ActiveRecord::Base; end

  let(:direction) { :up }

  before do
    ActiveRecord::Base.connection.add_column(
      :comments,
      :read,
      :boolean,
      default: false,
      null: false
    )

    Comment.reset_column_information

    Comment.create(read: false)
    Comment.create(read: false)
  end

  context 'running a migration with #update_all' do
    let(:version) { 9 }

    it 'updates all the required data' do
      run_a_migration(direction, version)

      expect(Comment.pluck(:read)).to match_array([true, true])
    end

    it 'marks the migration as up' do
      run_a_migration(direction, version)

      expect(current_migration_version).to eq(version)
    end
  end

  context 'running a migration with .upsert_all', if: defined?(Comment.upsert_all) do
    let(:version) { 30 }

    it 'updates all the required data' do
      run_a_migration(direction, version)

      expect(Comment.pluck(:author, :read)).to match_array([
        [nil, false],
        [nil, false],
        ["John", true],
        ["Smith", false],
      ])
    end

    it 'marks the migration as up' do
      run_a_migration(direction, version)

      expect(current_migration_version).to eq(version)
    end
  end

  context 'running a migration with #find_each' do
    let(:version) { 10 }

    it 'updates all the required data' do
      run_a_migration(direction, version)

      expect(Comment.pluck(:read)).to match_array([true, true])
    end

    it 'marks the migration as up' do
      run_a_migration(direction, version)

      expect(current_migration_version).to eq(version)
    end
  end

  context 'running a migration with ? interpolation' do
    let(:version) { 11 }

    it 'updates all the required data' do
      run_a_migration(direction, version)

      expect(Comment.pluck(:read)).to match_array([true, true])
    end

    it 'marks the migration as up' do
      run_a_migration(direction, version)

      expect(current_migration_version).to eq(version)
    end
  end

  context 'running a migration with named bind variables' do
    let(:version) { 12 }

    it 'updates all the required data' do
      run_a_migration(direction, version)

      expect(Comment.pluck(:read)).to match_array([true, true])
    end

    it 'marks the migration as up' do
      run_a_migration(direction, version)

      expect(current_migration_version).to eq(version)
    end
  end
end
