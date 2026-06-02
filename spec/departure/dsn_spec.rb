require "spec_helper"

describe Departure::DSN do
  let(:database) { "development" }
  let(:table_name) { "comments" }

  around do |example|
    ClimateControl.modify(env_var) do
      example.run
    end
  end

  describe "#to_s" do
    subject { described_class.new(database, table_name).to_s }
    let(:env_var) { {} }

    context "when a DSN suffix is not specified" do
      it { is_expected.to eq("D=development,t=comments") }
    end

    context "when a DSN suffix is specified" do
      let(:env_var) { {PERCONA_DSN_SUFFIX: "P=3306"} }

      it "tests for environment modification" do
        is_expected.to eq("D=development,t=comments,P=3306")
      end
    end
  end
end
