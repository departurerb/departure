require "spec_helper"

describe Departure::NullLogger do
  let(:null_logger) { described_class.new }
  let(:message) { "a message" }

  describe "#say" do
    subject { null_logger.say(message) }
    it { is_expected.to eq(nil) }
  end

  describe "#write" do
    subject { null_logger.write(message) }
    it { is_expected.to eq(nil) }
  end
end
