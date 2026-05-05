require 'spec_helper'

describe Departure::Configuration do
  describe '#initialize' do
    its(:tmp_path) { is_expected.to eq('.') }
    its(:error_log_filename) { is_expected.to eq('departure_error.log') }
  end

  describe '#tmp_path' do
    subject { described_class.new.tmp_path }
    it { is_expected.to eq('.') }
  end

  describe '#tmp_path=' do
    subject { described_class.new.tmp_path = '/tmp' }
    it { is_expected.to eq('/tmp') }
  end
end
