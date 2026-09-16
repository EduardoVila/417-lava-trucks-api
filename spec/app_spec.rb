# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe LavaTrucks::App do
  subject(:create_wash) { post '/api/washes', JSON.generate(payload), headers }

  let(:app) { described_class }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:payload) do
    { date: '2026-09-11', time: '09:30', customer: 'João Transportes',
      plate: 'ABC1D23', service: 'normal', amount_cents: 18_000,
      stage: 'waiting', paid: false, notes: '' }
  end
  let(:json) { JSON.parse(last_response.body) }
  let(:wash_id) { json.fetch('data').fetch('id') }

  it 'persists a wash with a normalized plate' do
    create_wash
    expect(last_response.status).to eq(201)
    expect(json['data']).to include('plate' => 'ABC1D23', 'paid' => false)
    get '/api/washes'
    expect(JSON.parse(last_response.body)['data'].length).to eq(1)
  end

  context 'with invalid amount' do
    let(:payload) { super().merge(amount_cents: 0) }

    it 'rejects zero' do
      create_wash
      expect(last_response.status).to eq(422)
    end
  end

  context 'with fractional cents' do
    let(:payload) { super().merge(amount_cents: 1.5) }

    it 'rejects fractions' do
      create_wash
      expect(last_response.status).to eq(422)
    end
  end

  context 'with invalid date' do
    let(:payload) { super().merge(date: '2026-02-30') }

    it 'rejects impossible dates' do
      create_wash
      expect(last_response.status).to eq(422)
    end
  end

  context 'with a paid wash missing payment method' do
    let(:payload) { super().merge(paid: true, paid_on: '2026-09-11') }

    it 'requires payment details' do
      create_wash
      expect(last_response.status).to eq(422)
    end
  end

  it 'receives a pending wash exactly once' do
    create_wash
    post "/api/washes/#{wash_id}/receive",
         JSON.generate(paid_on: '2026-09-12', payment_method: 'Pix'), headers
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['data']['paid']).to be(true)
    post "/api/washes/#{wash_id}/receive",
         JSON.generate(paid_on: '2026-09-13', payment_method: 'Dinheiro'), headers
    expect(last_response.status).to eq(409)
    get '/api/summary?from=2026-09-12&to=2026-09-12'
    expect(JSON.parse(last_response.body)['data']).to include('revenue_cents' => 0,
                                                              'received_cents' => 18_000,
                                                              'cash_cents' => 18_000)
  end

  it 'separates all pending balances from the selected revenue period' do
    create_wash
    get '/api/summary?from=2026-10-01&to=2026-10-31'
    expect(json['data']).to include('revenue_cents' => 0,
                                    'pending_cents' => 18_000)
  end

  it 'subtracts paid expenses from both period results' do
    create_wash
    post '/api/expenses', JSON.generate(date: '2026-09-11',
                                        description: 'Shampoo',
                                        category: 'Produtos',
                                        amount_cents: 2000,
                                        payment_method: 'Pix'), headers
    expect(last_response.status).to eq(201)
    get '/api/summary?from=2026-09-11&to=2026-09-11'
    expect(json['data']).to include('result_cents' => 16_000,
                                    'cash_cents' => -2000,
                                    'ticket_cents' => 18_000)
  end

  it 'supports edits to operational stage' do
    create_wash
    patch "/api/washes/#{wash_id}",
          JSON.generate(payload.merge(stage: 'washing')), headers
    expect(JSON.parse(last_response.body)['data']['stage']).to eq('washing')
  end

  it 'returns a structured 404' do
    post '/api/washes/999/receive', JSON.generate({}), headers
    expect(last_response.status).to eq(404)
    expect(json['error']).to be_a(String)
  end

  it 'rejects malformed JSON' do
    post '/api/washes', '{', headers
    expect(last_response.status).to eq(400)
  end

  it 'rejects a reversed date range' do
    get '/api/summary?from=2026-09-12&to=2026-09-11'
    expect(last_response.status).to eq(422)
  end

  it 'returns an empty summary without division errors' do
    get '/api/summary?from=2026-09-11&to=2026-09-11'
    expect(json['data']).to include('ticket_cents' => 0, 'count' => 0)
  end
end
