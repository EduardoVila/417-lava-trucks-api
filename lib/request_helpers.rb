# frozen_string_literal: true

module LavaTrucks
  module RequestHelpers
    def input
      request.body.rewind if request.body.respond_to?(:rewind)
      length = request.env['CONTENT_LENGTH'].to_i
      halt 413, JSON.generate(error: 'Requisição muito grande.') if length > 32_768
      raw = request.body.read(length).to_s

      parsed = JSON.parse(raw)
      halt 400, JSON.generate(error: 'Envie um objeto JSON.') unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError
      halt 400, JSON.generate(error: 'JSON inválido.')
    end

    def repository(table = 'washes')
      Repository.new(table)
    end

    def find!(repo = repository)
      repo.find(params[:id]) || halt(404, JSON.generate(error: 'Registro não encontrado.'))
    end

    def respond(data, code = 200)
      status code
      JSON.generate(data: data)
    end

    def period
      from = Validation.date(params['from'])
      to = Validation.date(params['to'])
      raise ValidationError, 'A data inicial deve ser anterior à final.' if from > to

      [from, to]
    end
  end
end
