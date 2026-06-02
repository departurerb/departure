require "spec_helper"

describe Lhm::Adapter, "#rename_column" do
  let(:migration) { double(:migration) }
  let(:table_name) { :comments }

  let(:adapter) { described_class.new(migration, table_name) }

  before do
    allow(migration).to(
      receive(:rename_column).with(table_name, column_name, new_column_name)
    )
  end

  before { adapter.rename_column(column_name, new_column_name) }

  let(:column_name) { :description }
  let(:new_column_name) { :new_description }

  it "calls #rename_column in the migration" do
    expect(migration).to(
      have_received(:rename_column)
      .with(table_name, column_name, new_column_name)
    )
  end
end
