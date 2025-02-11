require 'spec_helper'

describe Lhm::Adapter, '#remove_column' do
  let(:migration) { double(:migration) }
  let(:table_name) { :comments }

  let(:adapter) { described_class.new(migration, table_name) }

  before do
    allow(migration).to(
      receive(:remove_column).with(table_name, column_name)
    )
  end

  before { adapter.remove_column(column_name) }

  let(:column_name) { :some_id_field }

  it 'calls #remove_column in the migration' do
    expect(migration).to(
      have_received(:remove_column).with(table_name, column_name)
    )
  end
end
