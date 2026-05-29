shared_examples "column-definition method" do |method_name|
  let(:migration) { double(:migration) }
  let(:table_name) { :comments }
  let(:adapter) { described_class.new(migration, table_name) }

  before do
    allow(column).to receive(:attributes).and_return(attributes)
  end

  context "when the definition is passed as a String" do
    before { allow(Lhm::ColumnWithSql).to receive(:new).and_return(column) }

    before do
      allow(migration).to(
        receive(method_name).with(table_name, column_name, type, options)
      )
    end

    before { adapter.public_send(method_name, column_name, definition) }

    let(:column) { instance_double(Lhm::ColumnWithSql) }

    let(:definition) { "INT(11) DEFAULT NULL" }
    let(:column_name) { :some_id_field }
    let(:type) { :integer }
    let(:options) { {limit: 4, default: nil, null: true} }
    let(:attributes) { [type, options] }

    it "gets the attributes from the column object" do
      expect(column).to have_received(:attributes)
    end

    it "calls ##{method_name} in the migration" do
      expect(migration).to(
        have_received(method_name)
        .with(table_name, column_name, type, options)
      )
    end
  end

  context "when the definition is passed as a Symbol" do
    before do
      allow(Lhm::ColumnWithType).to receive(:new).and_return(column)
    end

    before do
      allow(migration).to(
        receive(method_name).with(table_name, column_name, definition)
      )
    end

    before { adapter.public_send(method_name, column_name, definition) }

    let(:column) { instance_double(Lhm::ColumnWithType) }

    let(:definition) { :integer }
    let(:column_name) { :some_id_field }
    let(:attributes) { [definition] }

    it "gets the attributes from the column object" do
      expect(column).to have_received(:attributes)
    end

    it "calls ##{method_name} in the migration" do
      expect(migration).to(
        have_received(method_name)
        .with(table_name, column_name, definition)
      )
    end
  end
end
