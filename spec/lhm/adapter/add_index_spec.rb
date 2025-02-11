require 'spec_helper'

describe Lhm::Adapter, '#add_index' do
  let(:migration) { double(:migration) }
  let(:table_name) { :comments }

  let(:adapter) { described_class.new(migration, table_name) }

  before do
    allow(migration).to(
      receive(:add_index).with(table_name, columns, options)
    )
  end

  let(:options) { {} }

  context 'when passing a single column' do
    before { adapter.add_index(columns) }

    let(:columns) { :some_id_field }

    it 'calls #add_index in the migration' do
      expect(migration).to(
        have_received(:add_index).with(table_name, columns, options)
      )
    end
  end

  context 'when passing an array of columns' do
    before { adapter.add_index(columns) }

    let(:columns) { [:some_id_field, :name] }

    it 'calls #add_index in the migration' do
      expect(migration).to(
        have_received(:add_index).with(table_name, columns, options)
      )
    end
  end

  context 'when passing also an index name' do
    before { adapter.add_index(columns, options[:name]) }

    let(:columns) { [:some_id_field, :name] }
    let(:options) { { name: 'index_name' } }

    it 'calls #add_index in the migration' do
      expect(migration).to(
        have_received(:add_index).with(table_name, columns, options)
      )
    end
  end
end
