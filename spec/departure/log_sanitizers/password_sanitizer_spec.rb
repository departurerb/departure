require "spec_helper"

describe Departure::LogSanitizers::PasswordSanitizer do
  subject(:password_sanitizer) { described_class.new(connection_details) }

  let(:password_argument) { "-p secret_password" }
  let(:connection_details) { double(:connection_details, password_argument: password_argument) }

  describe "#execute" do
    let(:text) { "pt-online-tools #{password_argument} execute alter table" }

    it "filters out password" do
      expect(password_sanitizer.execute(text)).to include(described_class::PASSWORD_REPLACEMENT)
      expect(password_sanitizer.execute(text)).to_not include(password_argument)
    end

    context "when password argument is blank" do
      let(:password_argument) { "" }
      it "returns text without changes" do
        expect(password_sanitizer.execute(text)).to eq text
      end
    end
  end
end
