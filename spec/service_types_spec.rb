# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'Service types' do
  let(:app) { LavaTrucks::App }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:type_payload) { { name: 'Lavagem completa', default_cents: 35_000, active: true } }
  let(:wash_payload) do
    { date: '2026-09-11', time: '10:00', customer: 'Cliente',
      plate: 'ABC1D23', service: type['code'], amount_cents: 32_000,
      paid: false, stage: 'waiting' }
  end
  let!(:type) { LavaTrucks::ServiceTypes.create(JSON.parse(JSON.generate(type_payload))) }
  let(:json) { JSON.parse(last_response.body) }

  it 'lists configurable types and default prices' do
    get '/api/service-types'
    expect(json['data']).to include(hash_including('name' => 'Lavagem completa', 'default_cents' => 35_000))
  end

  it 'accepts a custom type and a negotiated price' do
    post '/api/washes', JSON.generate(wash_payload), headers
    expect(last_response.status).to eq(201)
    expect(json['data']).to include('service_name' => 'Lavagem completa', 'amount_cents' => 32_000)
  end

  it 'preserves the name and amount of earlier services after a price change' do
    post '/api/washes', JSON.generate(wash_payload), headers
    patch "/api/service-types/#{type['code']}",
          JSON.generate(type_payload.merge(name: 'Completa premium', default_cents: 40_000)), headers
    expect(last_response.status).to eq(200)
    get '/api/washes'
    expect(json['data'].first).to include('service_name' => 'Lavagem completa', 'amount_cents' => 32_000)
  end

  it 'rejects inactive types in new washes' do
    patch "/api/service-types/#{type['code']}", JSON.generate(type_payload.merge(active: false)), headers
    post '/api/washes', JSON.generate(wash_payload), headers
    expect(last_response.status).to eq(422)
  end

  it 'rejects duplicate names regardless of case' do
    post '/api/service-types', JSON.generate(type_payload.merge(name: 'lavagem completa')), headers
    expect(last_response.status).to eq(422)
  end

  it 'includes custom services in the summary' do
    post '/api/washes', JSON.generate(wash_payload), headers
    get '/api/summary?from=2026-09-11&to=2026-09-11'
    expect(json['data']['by_service']).to include(hash_including('service' => type['code'], 'count' => 1))
  end
end
