require "spec_helper"

describe Departure::Option do
  describe ".from_string" do
    it "gets the name and value" do
      expect(described_class).to receive(:new).with("--arg", "value")
      described_class.from_string("--arg=value")
    end

    context "when given a name in short form" do
      it "gets the short name and value" do
        expect(described_class).to receive(:new).with("-A", "utf8")
        described_class.from_string("-A utf8")
      end
    end

    context "when given a name only" do
      it "gets the name" do
        expect(described_class).to receive(:new).with("--quiet", nil)
        described_class.from_string("--quiet")
      end

      context "in short form" do
        it "gets the short name" do
          expect(described_class).to receive(:new).with("-q", nil)
          described_class.from_string("-q")
        end
      end
    end

    context "when given an array value" do
      it "gets the name and array value" do
        expect(described_class).to receive(:new).with("--max-load", "Threads_running=100,Threads_created=500")
        described_class.from_string("--max-load Threads_running=100,Threads_created=500")
      end
    end
  end

  describe "#name" do
    subject { option.name }

    context "when option is initialized with a long-named command-line argument" do
      let(:option) { described_class.new("--dry-run") }
      it { is_expected.to eq("--dry-run") }
    end

    context "when option is initialized with a short form command-line argument" do
      let(:option) { described_class.new("-q") }
      it { is_expected.to eq("-q") }
    end

    context "when option is initialized with a name" do
      let(:option) { described_class.new("no-check-alter") }
      it { is_expected.to eq("--no-check-alter") }
    end
  end

  describe "#==" do
    subject { option == other_option }
    let(:option) { described_class.new("arg", "bar") }

    context "when the options have different name" do
      let(:other_option) { described_class.new("other_arg", "lol") }
      it { is_expected.to be_falsy }
    end

    context "when the options have the same name" do
      let(:other_option) { described_class.new("arg", "lol") }
      it { is_expected.to be_truthy }
    end
  end

  describe "#eql?" do
    subject { option.eql?(other_option) }
    let(:option) { described_class.new("arg", "bar") }

    context "when the options have different name" do
      let(:other_option) { described_class.new("other_arg", "lol") }
      it { is_expected.to be_falsy }
    end

    context "when the options have the same name" do
      let(:other_option) { described_class.new("arg", "lol") }
      it { is_expected.to be_truthy }
    end
  end

  describe "#hash" do
    subject { option.hash }
    let(:option) { described_class.new("arg", "bar") }

    it { is_expected.to eq("--arg".hash) }
  end

  describe "#to_s" do
    subject { option.to_s }

    context "when there is no value" do
      let(:option) { described_class.new("arg") }
      it { is_expected.to eq("--arg") }
    end

    context "when there is value" do
      let(:option) { described_class.new("arg", "bar") }
      it { is_expected.to eq("--arg=bar") }
    end

    context "when the value is an array" do
      let(:option) { described_class.new("max-load", "Threads_running=50") }
      it { is_expected.to eq("--max-load Threads_running=50") }
    end
  end
end
