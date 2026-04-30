require "spec_helper"

describe Departure::LoggerFactory do
  describe ".build" do
    context "when :verbose is set as true" do
      subject { described_class.build(verbose: true) }
      it { is_expected.to be_a(Departure::Logger) }
    end

    context "when :verbose is set as false" do
      subject { described_class.build(verbose: false) }
      it { is_expected.to be_a(Departure::NullLogger) }
    end

    context "when :verbose is not specified" do
      subject { described_class.build }
      it { is_expected.to be_a(Departure::Logger) }
    end
  end
end
