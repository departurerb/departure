require 'spec_helper'

RSpec.describe VersionCompatibility do
  describe '.compatible?' do
    context 'direct matches' do
      it 'returns true when compatible' do
        expect(VersionCompatibility.matches?('8.0.2', '8.0.2')).to be true
      end

      it 'returns false when not compatible' do
        expect(VersionCompatibility.matches?('8.0.2', '8.0.3')).to be false
      end
    end

    context 'less than matches' do
      it 'returns true when compatible' do
        expect(VersionCompatibility.matches?('8.0.2', '< 8.0.3')).to be true
      end

      it 'returns false when not compatible' do
        expect(VersionCompatibility.matches?('8.0.4', '< 8.0.3')).to be false
      end
    end

    context 'squigly matches' do
      it 'returns true when compatible' do
        expect(VersionCompatibility.matches?('7.0.2', '~> 7')).to be true
        expect(VersionCompatibility.matches?('7.1.2', '~> 7')).to be true
        expect(VersionCompatibility.matches?('7.1.2', '~> 7.1')).to be true
      end

      it 'returns false when not compatible' do
        expect(VersionCompatibility.matches?('8.0.2', '~> 7.1')).to be false
      end
    end
  end
end
