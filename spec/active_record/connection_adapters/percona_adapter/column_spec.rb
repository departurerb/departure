require 'spec_helper'

describe ActiveRecord::ConnectionAdapters::DepartureAdapter::Column do
  let(:field) { double(:field) }
  let(:default) { double(:default) }
  let(:cast_type) do
    if defined?(ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::MysqlString)
      ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::MysqlString.new
    else
      ActiveRecord::Type.lookup(:string, adapter: :mysql2)
    end
  end
  let(:metadata) do
    ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(
      type: cast_type.type,
      sql_type: type,
      limit: cast_type.limit
    )
  end
  let(:mysql_metadata) do
    ActiveRecord::ConnectionAdapters::MySQL::TypeMetadata.new(metadata)
  end
  let(:type) { 'VARCHAR' }
  let(:null) { double(:null) }
  let(:collation) { double(:collation) }

  let(:column) do
    if ActiveRecord::VERSION::STRING >= '6.1'
      described_class.new('field', 'default', mysql_metadata, null, collation: 'collation')
    else
      described_class.new(field, default, mysql_metadata, null, collation: collation)
    end
  end

  describe '#adapter' do
    subject { column.adapter }
    it do
      is_expected.to eq(
        ActiveRecord::ConnectionAdapters::DepartureAdapter
      )
    end
  end
end
