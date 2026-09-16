# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe LavaTrucks::Validation do
  describe '.amount' do
    subject(:validate) { described_class.amount(value) }

    [nil, false, '18000', -1, 100_000_001, 0.5].each do |invalid|
      context "with #{invalid.inspect}" do
        let(:value) { invalid }

        it('rejects the value') { expect { validate }.to raise_error(LavaTrucks::ValidationError) }
      end
    end
  end

  describe '.plate' do
    it 'normalizes spaces, hyphens and case' do
      expect(described_class.plate('abc-1d23')).to eq('ABC1D23')
      expect(described_class.plate('ABC 1234')).to eq('ABC1234')
    end
  end

  describe '.payment' do
    subject(:validate) { described_class.payment(payload, '2026-09-11') }

    let(:payload) { { 'paid_on' => '2026-09-10', 'payment_method' => 'Pix' } }

    it 'rejects receipt dated before the service' do
      expect { validate }.to raise_error(LavaTrucks::ValidationError)
    end
  end
end
