require 'spec_helper'

describe Departure::Logger do
  let(:logger) { described_class.new(sanitizers) }
  let(:sanitizers) { [] }

  describe '#say' do
    let(:message) { 'a random message' }

    context 'when the subitem options is not specified' do
      it 'prints the message to the stdout' do
        expect(logger).to receive(:puts).with("-- #{message}")
        logger.say(message)
      end
    end

    context 'when the subitem option is specified as false' do
      it 'prints the message to the stdout' do
        expect(logger).to receive(:puts).with("-- #{message}")
        logger.say(message, subitem: false)
      end
    end

    context 'when the subitem option is specified as true' do
      it 'prints the message to the stdout' do
        expect(logger).to receive(:puts).with("   -> #{message}")
        logger.say(message, subitem: true)
      end
    end

    it 'sends the output to the stdout' do
      expect(logger).to receive(:puts).with(/random message/)
      logger.say('random message')
    end
  end

  describe '#write' do
    let(:text) { 'a text' }

    it 'prints the text to the stdout' do
      expect(logger).to receive(:puts).with(text)
      logger.write(text)
    end

    context 'when sanitizers are passed' do
      let(:sanitized_text) { 'a sanitized text' }
      let(:sanitizer) { double(:sanitizer, execute: sanitized_text) }
      let(:sanitizers) { [sanitizer] }

      it 'calls execute on passed sanitizers' do
        expect(sanitizer).to receive(:execute)
        logger.write(text)
      end

      it 'returns sanitized text' do
        expect(logger).to receive(:puts).with(sanitized_text)
        logger.write(text)
      end
    end
  end

  describe '#write_no_newline' do
    let(:text) { 'a text' }
    let(:sanitized_text) { 'a sanitized text' }
    let(:sanitizer) { double(:sanitizer, execute: sanitized_text) }
    let(:sanitizers) { [sanitizer] }

    context 'when sanitizers are passed' do
      it 'calls execute on passed sanitizers' do
        expect(sanitizer).to receive(:execute)
        logger.write_no_newline(text)
      end

      it 'returns sanitized text' do
        expect(logger).to receive(:print).with(sanitized_text)
        logger.write_no_newline(text)
      end
    end
  end
end
