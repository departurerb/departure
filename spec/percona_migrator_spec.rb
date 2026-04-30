require "spec_helper"

describe Departure do
  describe ".configure" do
    it "yields the configuration object" do
      expect do |b|
        described_class.configure(&b)
      end.to yield_with_args(kind_of(Departure::Configuration))
    end
  end
end
