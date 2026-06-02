require "spec_helper"

describe Lhm::Adapter, "#remove_index" do
  let(:migration) { double(:migration) }
  let(:table_name) { :comments }

  let(:adapter) { described_class.new(migration, table_name) }

  context "when passing a single column" do
    before do
      allow(migration).to(
        receive(:remove_index).with(table_name, {column: columns})
      )
    end

    before { adapter.remove_index(columns) }

    let(:columns) { :some_id_field }

    it "calls #remove_index in the migration" do
      expect(migration).to(
        have_received(:remove_index).with(table_name, {column: columns})
      )
    end
  end

  context "when passing an array of columns" do
    before do
      allow(migration).to(
        receive(:remove_index).with(table_name, {column: columns})
      )
    end

    before { adapter.remove_index(columns) }

    let(:columns) { [:some_id_field, :name] }

    it "calls #remove_index in the migration" do
      expect(migration).to(
        have_received(:remove_index).with(table_name, {column: columns})
      )
    end
  end

  context "when passing also an index name" do
    before do
      allow(migration).to(
        receive(:remove_index).with(table_name, {name: index_name})
      )
    end

    before { adapter.remove_index(columns, index_name) }

    let(:columns) { [:some_id_field, :name] }
    let(:index_name) { "some_id_field_index" }

    it "calls #remove_index in the migration" do
      expect(migration).to(
        have_received(:remove_index).with(table_name, {name: index_name})
      )
    end
  end
end
