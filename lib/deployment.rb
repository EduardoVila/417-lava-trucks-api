# frozen_string_literal: true

require 'uri'

module LavaTrucks
  module Deployment
    PRODUCTION = ENV.fetch('RACK_ENV', ENV.fetch('APP_ENV', 'development')) == 'production'
    ORIGINS = ENV.fetch('ALLOWED_ORIGINS', PRODUCTION ? '' : 'http://localhost:4173,http://127.0.0.1:4173,http://localhost:4567,http://127.0.0.1:4567').split(',').map(&:strip).reject(&:empty?).freeze
    HOSTS = ENV.fetch('ALLOWED_HOSTS', 'localhost,127.0.0.1,[::1]').split(',').map(&:strip).freeze
    raise 'Configure ALLOWED_ORIGINS with exact HTTPS frontend origins' if PRODUCTION && (ORIGINS.empty? || ORIGINS.any? { |origin| !origin.start_with?('https://') || origin.include?('*') })
    raise 'DATABASE_URL is required in production' if PRODUCTION && ENV.fetch('DATABASE_URL', '').empty?
    raise 'SESSION_SECRET must contain at least 64 bytes' if ENV.fetch('SESSION_SECRET', '').bytesize < 64
  end

  # Runs before session/protection middleware, including unauthenticated preflight.
  class Cors
    def initialize(app)
      @app = app
    end

    def call(env)
      origin = env['HTTP_ORIGIN']
      allowed = Deployment::ORIGINS.include?(origin)
      mutation = %w[POST PATCH PUT DELETE].include?(env['REQUEST_METHOD'])
      if (origin && !allowed) || (Deployment::PRODUCTION && mutation && !origin)
        return [403, { 'content-type' => 'application/json' }, ['{"error":"Origem não permitida."}']]
      end
      headers = { 'vary' => 'Origin' }
      if allowed
        headers.merge!('access-control-allow-origin' => origin, 'access-control-allow-credentials' => 'true',
                       'access-control-allow-methods' => 'GET, POST, PATCH, DELETE, OPTIONS',
                       'access-control-allow-headers' => 'Content-Type', 'access-control-max-age' => '600')
      end
      return [204, headers, []] if env['REQUEST_METHOD'] == 'OPTIONS'

      status, response_headers, body = @app.call(env)
      [status, response_headers.merge(headers), body]
    end
  end
end
