# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'Data integrity and request boundaries' do
  let(:app) { LavaTrucks::App }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:payload) do
    { 'date' => '2026-09-11', 'time' => '10:00', 'customer' => '=SUM(1,2)',
      'plate' => 'ABC1D23', 'service' => 'normal', 'amount_cents' => 18_029,
      'stage' => 'done', 'paid' => true, 'paid_on' => '2026-09-11',
      'payment_method' => 'Pix', 'notes' => 'teste' }
  end
  let!(:wash) do
    LavaTrucks::Repository.new('washes').create(LavaTrucks::Validation.wash(payload))
  end
  let(:json) { JSON.parse(last_response.body) }

  it 'does not alter a received amount' do
    patch "/api/washes/#{wash['id']}",
          JSON.generate(payload.merge('amount_cents' => 1)), headers
    expect(last_response.status).to eq(409)
    expect(LavaTrucks::Repository.new('washes').find(wash['id'])['amount_cents']).to eq(18_029)
  end

  it 'does not reopen a received wash' do
    patch "/api/washes/#{wash['id']}", JSON.generate(payload.merge('paid' => false)), headers
    expect(last_response.status).to eq(409)
  end

  it 'rejects a cross-origin write' do
    post '/api/washes', JSON.generate(payload), headers.merge('HTTP_ORIGIN' => 'https://example.com')
    expect(last_response.status).to eq(403)
  end

  it 'rejects non-JSON submissions' do
    post '/api/washes', payload
    expect(last_response.status).to eq(415)
  end

  it 'rejects an oversized request' do
    post '/api/washes', JSON.generate(payload.merge('notes' => 'x' * 33_000)), headers
    expect(last_response.status).to eq(413)
  end

  it 'rejects an array instead of an object' do
    post '/api/washes', '[]', headers
    expect(last_response.status).to eq(400)
  end

  it 'neutralizes spreadsheet formulas in CSV exports' do
    get '/api/export/washes'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("'=SUM(1,2)")
    expect(last_response.body).to include('18029')
  end

  it 'rejects an unknown export collection' do
    get '/api/export/unknown'
    expect(last_response.status).to eq(404)
  end
end
