# frozen_string_literal: true

require 'securerandom'

module LavaTrucks
  class ServiceTypes
    def self.all
      Database.connection.execute('SELECT * FROM service_types ORDER BY name').map do |row|
        row.merge('active' => row['active'] == 1)
      end
    end

    def self.find(code)
      all.find { |row| row['code'] == code }
    end

    def self.validate_code(code)
      service = find(code)
      raise ValidationError, 'Tipo de lavagem inexistente ou inativo.' unless service&.fetch('active')

      service
    end

    def self.create(input)
      attributes = validate(input)
      code = SecureRandom.uuid
      Database.connection.execute(
        'INSERT INTO service_types (code, name, default_cents, active) VALUES (?, ?, ?, ?)',
        [code, *attributes]
      )
      find(code)
    end

    def self.update(code, input)
      attributes = validate(input, code)
      Database.connection.execute(
        'UPDATE service_types SET name = ?, default_cents = ?, active = ? WHERE code = ?',
        [*attributes, code]
      )
      find(code)
    end

    def self.validate(input, code = nil)
      name = Validation.text(input['name'], 'Nome do tipo de lavagem', max: 80)
      duplicate = all.any? { |row| row['code'] != code && row['name'].downcase == name.downcase }
      raise ValidationError, 'Já existe um tipo de lavagem com esse nome.' if duplicate

      price = input['default_cents'].nil? ? nil : Validation.amount(input['default_cents'])
      active = Validation.choice(input['active'], [true, false], 'Situação')
      [name, price, active ? 1 : 0]
    end
    private_class_method :validate
  end
end
