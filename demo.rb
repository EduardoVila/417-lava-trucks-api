# frozen_string_literal: true

# An isolated database, never the default working database.
ENV['DATABASE_PATH'] = File.expand_path('data/demo.db', __dir__)
require_relative 'lib/database'
require_relative 'lib/validation'
require_relative 'lib/repository'

unless LavaTrucks::Repository.new('washes').all.empty?
  abort 'A base demo já possui registros. Nenhum dado foi alterado.'
end

today = Time.now.getlocal('-03:00').to_date
names = ['Transportes Costa', 'João da Silva', 'Expresso Sul', 'Carlos Henrique',
         'Transportadora Lima', 'Pedro Martins', 'Rodovias Cargas']
plates = %w[MKT4B17 ABC1D23 QHZ8A42 JKL4F56 RLT2B89 MNO3G45 PQR7H89]
14.times do |index|
  date = (today - (index / 3)).iso8601
  paid = index % 4 != 1
  attributes = {
    'date' => date, 'time' => format('%<hour>02d:%<minute>02d', hour: 8 + (index % 9), minute: (index % 4) * 15),
    'customer' => names[index % names.length], 'plate' => plates[index % plates.length],
    'service' => index % 3 == 1 ? 'hot' : 'normal',
    'amount_cents' => index % 3 == 1 ? 28_000 : 18_000,
    'stage' => index < 3 ? %w[waiting washing done][index] : 'done',
    'paid' => paid, 'paid_on' => paid ? date : nil,
    'payment_method' => paid ? 'Pix' : nil, 'notes' => 'Registro fictício de demonstração.'
  }
  LavaTrucks::Repository.new('washes').create(LavaTrucks::Validation.wash(attributes))
end

[['Shampoo automotivo', 'Produtos', 24_000], ['Conta de água', 'Água', 18_500],
 ['Manutenção da lavadora', 'Manutenção', 12_000]].each do |description, category, amount|
  LavaTrucks::Repository.new('expenses').create(
    LavaTrucks::Validation.expense('date' => today.iso8601,
                                   'description' => description,
                                   'category' => category, 'amount_cents' => amount,
                                   'payment_method' => 'Pix',
                                   'notes' => 'Registro fictício de demonstração.')
  )
end
puts 'Base de demonstração criada em api/data/demo.db.'
