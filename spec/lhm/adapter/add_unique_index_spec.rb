require "spec_helper"

describe Lhm::Adapter, "#add_unique_index" do
  let(:migration) { double(:migration) }
  let(:table_name) { :comments }

  let(:adapter) { described_class.new(migration, table_name) }

  context "when passing a single column" do
    before do
      allow(migration).to(
        receive(:add_index).with(table_name, columns, {unique: true})
      )
    end

    before { adapter.add_unique_index(columns) }

    let(:columns) { :some_id_field }

    it "calls #add_index in the migration" do
      expect(migration).to(
        have_received(:add_index).with(table_name, columns, {unique: true})
      )
    end
  end

  context "when passing an array of columns" do
    before do
      allow(migration).to(
        receive(:add_index).with(table_name, columns, {unique: true})
      )
    end

    before { adapter.add_unique_index(columns) }

    let(:columns) { [:some_id_field, :name] }

    it "calls #add_index in the migration" do
      expect(migration).to(
        have_received(:add_index).with(table_name, columns, {unique: true})
      )
    end
  end

  context "when passing also an index name" do
    before do
      allow(migration).to(
        receive(:add_index)
        .with(table_name, columns, {unique: true, name: index_name})
      )
    end

    before { adapter.add_unique_index(columns, index_name) }

    let(:columns) { [:some_id_field, :name] }
    let(:index_name) { "some_id_field_and_name_index" }

    it "calls #add_index in the migration" do
      expect(migration).to(
        have_received(:add_index)
        .with(table_name, columns, {unique: true, name: index_name})
      )
    end
  end
end
