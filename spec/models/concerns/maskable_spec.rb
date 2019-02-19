# frozen_string_literal: true

require 'spec_helper'

describe Maskable do
  let(:variable) { build(:ci_variable) }

  describe 'REGEX' do
    subject { Maskable::REGEX }

    it 'does not match strings shorter than 8 letters' do
      expect(subject.match?('hello')).to eq(false)
    end

    it 'does not match strings with spaces' do
      expect(subject.match?('hello world')).to eq(false)
    end

    it 'does not match strings with shell variables' do
      expect(subject.match?('hello$VARIABLEworld')).to eq(false)
    end

    it 'does not match strings with escape characters' do
      expect(subject.match?('hello\rworld')).to eq(false)
    end

    it 'does not match strings that span more than one line' do
      string = <<~EOS
        hello
        world
      EOS

      expect(subject.match?(string)).to eq(false)
    end

    it 'matches valid strings' do
      expect(subject.match?('helloworld')).to eq(true)
    end
  end

  describe '#to_runner_variable' do
    subject { variable.to_runner_variable }

    it 'exposes the masked attribute' do
      expect(subject).to include(:masked)
    end
  end
end
