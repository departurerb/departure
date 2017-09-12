require 'spec_helper'

describe Lhm::ColumnWithSql do
  let(:name) { :some_field_name }
  let(:column) { described_class.new(name, definition) }

  describe '#attributes' do
    subject { column.attributes }

    context 'when defining INT' do
      let(:definition) { 'INT' }

      its([0]) { is_expected.to eq(:integer) }
      its([1]) { is_expected.to eq(limit: 4, default: nil, null: true) }

      context 'with DEFAULT' do
        subject { column.attributes[1] }

        let(:definition) { 'INT DEFAULT NULL' }
        its([:default]) { is_expected.to eq(nil) }
      end

      context 'with NOT NULL' do
        subject { column.attributes[1] }

        let(:definition) { 'INT NOT NULL' }
        its([:null]) { is_expected.to eq(false) }
      end

      context 'with limit' do
        subject { column.attributes[1] }

        let(:definition) { 'INT(11)' }
        its([:limit]) { is_expected.to eq(4) }
      end
    end

    context 'when defining MEDIUMINT' do
      let(:definition) { 'MEDIUMINT' }

      its([0]) { is_expected.to eq(:integer) }
      its([1]) { is_expected.to eq(limit: 3, default: nil, null: true) }

      context 'with DEFAULT' do
        subject { column.attributes[1] }

        let(:definition) { 'MEDIUMINT DEFAULT 0' }
        its([:default]) { is_expected.to eq('0') }
      end

      context 'with NOT NULL' do
        subject { column.attributes[1] }

        let(:definition) { 'MEDIUMINT NOT NULL' }
        its([:null]) { is_expected.to eq(false) }
      end

      context 'with limit' do
        subject { column.attributes[1] }

        let(:definition) { 'MEDIUMINT(11)' }
        its([:limit]) { is_expected.to eq(3) }
      end
    end

    context 'when defining TINYINT' do
      let(:definition) { 'TINYINT' }

      its([0]) { is_expected.to eq(:integer) }
      its([1]) { is_expected.to eq(limit: 1, default: nil, null: true) }

      context 'with DEFAULT' do
        subject { column.attributes[1] }

        let(:definition) { 'TINYINT default 0' }
        its([:default]) { is_expected.to eq('0') }
      end

      context 'with NOT NULL' do
        subject { column.attributes[1] }

        let(:definition) { 'TINYINT NOT NULL' }
        its([:null]) { is_expected.to eq(false) }
      end

      context 'with limit' do
        subject { column.attributes[1] }

        # ActiveRecord 5.1.x special cases tinyint(1) to be Type::Boolean with
        # no limit specified in abstract AbstractMysqlAdapter. Perhaps this is
        # a bug and it should do:
        #
        # m.register_type %r(^tinyint\(1\))i, Type::Boolean.new(limit: 1) if emulate_booleans
        #
        # But until that changes, this test will return nil for a limit instead
        # of 1, as it did previously.
        let(:definition) { 'TINYINT(1)' }
        its([:limit]) { is_expected.to eq(1) }
      end
    end

    # TODO: FLOAT(M, D) ? see:
    # https://dev.mysql.com/doc/refman/5.5/en/floating-point-types.html
    context 'when defining FLOAT' do
      let(:definition) { 'FLOAT' }

      its([0]) { is_expected.to eq(:float) }
      its([1]) { is_expected.to eq(limit: 24, default: nil, null: true) }

      context 'with DEFAULT' do
        subject { column.attributes[1] }

        let(:definition) { 'FLOAT DEFAULT 0' }
        its([:default]) { is_expected.to eq('0') }
      end

      context 'with NOT NULL' do
        subject { column.attributes[1] }

        let(:definition) { 'FLOAT NOT NULL' }
        its([:null]) { is_expected.to eq(false) }
      end
    end

    context 'when defining VARCHAR' do
      let(:definition) { 'VARCHAR' }

      its([0]) { is_expected.to eq(:string) }
      its([1]) { is_expected.to eq(limit: nil, default: nil, null: true) }

      context 'with DEFAULT' do
        subject { column.attributes[1] }

        let(:definition) { "VARCHAR DEFAULT 'foo'" }
        its([:default]) { is_expected.to eq('foo') }
      end

      context 'with NOT NULL' do
        subject { column.attributes[1] }

        let(:definition) { 'VARCHAR NOT NULL' }
        its([:null]) { is_expected.to eq(false) }
      end

      context 'with limit' do
        subject { column.attributes[1] }

        let(:definition) { 'VARCHAR(255)' }
        its([:limit]) { is_expected.to eq(255) }
      end
    end

    context 'when defining TEXT' do
      let(:definition) { 'TEXT' }

      its([0]) { is_expected.to eq(:text) }
      its([1]) { is_expected.to eq(limit: 65_535, default: nil, null: true) }

      context 'with NOT NULL' do
        subject { column.attributes[1] }

        let(:definition) { 'TEXT NOT NULL' }
        its([:null]) { is_expected.to eq(false) }
      end
    end

    context 'when defining DATE' do
      let(:definition) { 'DATE' }

      its([0]) { is_expected.to eq(:date) }
      its([1]) { is_expected.to eq(limit: nil, default: nil, null: true) }

      context 'with DEFAULT' do
        subject { column.attributes[1] }

        let(:definition) { 'DATE DEFAULT NULL' }
        its([:default]) { is_expected.to eq(nil) }
      end

      context 'with NOT NULL' do
        subject { column.attributes[1] }

        let(:definition) { 'DATE NOT NULL' }
        its([:null]) { is_expected.to eq(false) }
      end
    end

    context 'when defining DATETIME' do
      let(:definition) { 'DATETIME' }

      its([0]) { is_expected.to eq(:datetime) }
      its([1]) { is_expected.to eq(limit: nil, default: nil, null: true) }

      context 'with DEFAULT' do
        subject { column.attributes[1] }

        let(:definition) { "DATETIME DEFAULT '2016-02-24 13:21:00'" }
        its([:default]) { is_expected.to eq('2016-02-24 13:21:00') }
      end

      context 'with NOT NULL' do
        subject { column.attributes[1] }

        let(:definition) { 'DATETIME NOT NULL' }
        its([:null]) { is_expected.to eq(false) }
      end
    end

    context 'when defining TIMESTAMP' do
      let(:definition) { 'TIMESTAMP' }

      its([0]) { is_expected.to eq(:datetime) }
      its([1]) { is_expected.to eq(limit: nil, default: nil, null: true) }

      context 'with DEFAULT' do
        subject { column.attributes[1] }

        let(:definition) { "TIMESTAMP DEFAULT '2016-02-24 13:21:00'" }
        its([:default]) { is_expected.to eq('2016-02-24 13:21:00') }
      end

      context 'with NOT NULL' do
        subject { column.attributes[1] }

        let(:definition) { 'TIMESTAMP NOT NULL' }
        its([:null]) { is_expected.to eq(false) }
      end
    end

    context 'when defining BINARY' do
      let(:definition) { 'BINARY' }

      its([0]) { is_expected.to eq(:binary) }
      its([1]) { is_expected.to eq(limit: nil, default: nil, null: true) }

      context 'with DEFAULT' do
        subject { column.attributes[1] }

        let(:definition) { "BINARY DEFAULT 'a'" }
        its([:default]) { is_expected.to eq('a') }
      end

      context 'with NOT NULL' do
        subject { column.attributes[1] }

        let(:definition) { 'BINARY NOT NULL' }
        its([:null]) { is_expected.to eq(false) }
      end

      context 'with limit' do
        subject { column.attributes[1] }

        let(:definition) { 'BINARY(3)' }
        its([:limit]) { is_expected.to eq(3) }
      end
    end

    context 'when defining BOOLEAN' do
      let(:definition) { 'BOOLEAN' }

      its([0]) { is_expected.to eq(:boolean) }
      its([1]) { is_expected.to eq(limit: nil, default: nil, null: true) }

      context 'with DEFAULT' do
        subject { column.attributes[1] }

        let(:definition) { 'BOOLEAN DEFAULT FALSE' }
        its([:default]) { is_expected.to eq('FALSE') }
      end

      context 'with NOT NULL' do
        subject { column.attributes[1] }

        let(:definition) { 'BOOLEAN NOT NULL' }
        its([:null]) { is_expected.to eq(false) }
      end
    end
  end
end
