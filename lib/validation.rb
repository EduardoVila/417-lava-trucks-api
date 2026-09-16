# frozen_string_literal: true

require 'date'

module LavaTrucks
  class ValidationError < StandardError; end

  module Validation
    METHODS = %w[Pix Dinheiro Cartão Boleto Outro].freeze
    CATEGORIES = %w[Produtos Diesel Água Luz Salários Manutenção Impostos Outros].freeze

    def self.text(value, label, max: 120)
      valid = value.is_a?(String) && !value.strip.empty? && value.length <= max
      raise ValidationError, "#{label}: preenchimento obrigatório (até #{max} caracteres)." unless valid

      value.strip
    end

    def self.date(value)
      valid = value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      raise ValidationError, 'Informe uma data válida.' unless valid

      parsed = Date.iso8601(value)
      raise ValidationError, 'A data deve estar entre 2000 e 2100.' unless (2000..2100).cover?(parsed.year)

      value
    rescue Date::Error
      raise ValidationError, 'Informe uma data válida.'
    end

    def self.amount(value)
      valid = value.is_a?(Integer) && value.positive? && value <= 100_000_000
      raise ValidationError, 'O valor deve ser positivo, em centavos inteiros, até R$ 1.000.000.' unless valid

      value
    end

    def self.choice(value, choices, label)
      raise ValidationError, "#{label}: escolha uma opção válida." unless choices.include?(value)

      value
    end

    def self.notes(value)
      value ||= ''
      unless value.is_a?(String) && value.length <= 1000
        raise ValidationError,
              'Observação: máximo de 1.000 caracteres.'
      end

      value.strip
    end

    def self.payment(input, service_date)
      paid_on = date(input['paid_on'])
      raise ValidationError, 'Recebimento não pode ser anterior ao serviço.' if paid_on < service_date

      { 'paid_on' => paid_on,
        'payment_method' => choice(input['payment_method'], METHODS, 'Pagamento') }
    end

    def self.time(value)
      valid = value.is_a?(String) && value.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
      raise ValidationError, 'Informe um horário válido.' unless valid

      value
    end

    def self.plate(value)
      normalized = text(value, 'Placa', max: 10).upcase.gsub(/[ -]/, '')
      unless normalized.match?(/\A[A-Z]{3}\d[A-Z0-9]\d{2}\z/)
        raise ValidationError, 'Informe uma placa brasileira válida.'
      end

      normalized
    end

    def self.wash(input)
      raise ValidationError, 'Informe a situação de pagamento.' unless [true, false].include?(input['paid'])

      record = wash_details(input).merge('paid' => input['paid'] ? 1 : 0,
                                         'paid_on' => nil, 'payment_method' => nil)
      record.merge!(payment(input, record['date'])) if input['paid']
      record
    end

    def self.wash_details(input)
      { 'date' => date(input['date']), 'time' => time(input['time']),
        'customer' => text(input['customer'], 'Cliente'), 'plate' => plate(input['plate']),
        'service' => text(input['service'], 'Serviço', max: 40),
        'amount_cents' => amount(input['amount_cents']),
        'stage' => choice(input['stage'], %w[waiting washing done], 'Etapa'),
        'notes' => notes(input['notes']) }
    end

    def self.expense(input)
      { 'date' => date(input['date']),
        'description' => text(input['description'], 'Descrição'),
        'category' => choice(input['category'], CATEGORIES, 'Categoria'),
        'amount_cents' => amount(input['amount_cents']),
        'payment_method' => choice(input['payment_method'], METHODS, 'Pagamento'),
        'notes' => notes(input['notes']) }
    end
  end
end
