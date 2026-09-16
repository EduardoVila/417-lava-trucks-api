# frozen_string_literal: true

require 'bcrypt'
require 'base64'
require 'json'
require 'openssl'

module LavaTrucks
  module Auth
    SESSION_KEY = 'lava_user_id'
    TOKEN_TTL = 7 * 24 * 60 * 60

    def self.find(id)
      Database.connection.get_first_row(
        'SELECT id, name, username, role, active, tour_completed FROM users WHERE id = ? AND active = 1', [id]
      )
    end

    def self.public_user(row)
      return nil unless row
      row.slice('id', 'name', 'username', 'role', 'active').merge(
        'tour_completed' => row['tour_completed'].to_s.split(',').reject(&:empty?),
      )
    end

    def self.authenticate(username, password)
      row = Database.connection.get_first_row('SELECT * FROM users WHERE username = ? AND active = 1', [username.to_s.strip])
      return nil unless row && BCrypt::Password.new(row['password_digest']) == password.to_s

      row
    rescue BCrypt::Errors::InvalidHash
      nil
    end

    # Signed, short-lived bearer token used by clients where cross-site cookies
    # are blocked (for example Firebase Hosting to a Render API on mobile).
    def self.issue_token(row)
      payload = JSON.generate('sub' => row['id'].to_i, 'exp' => Time.now.to_i + TOKEN_TTL)
      encoded = Base64.urlsafe_encode64(payload, padding: false)
      signature = Base64.urlsafe_encode64(OpenSSL::HMAC.digest('SHA256', secret, encoded), padding: false)
      "#{encoded}.#{signature}"
    end

    def self.find_token(token)
      encoded, signature = token.to_s.split('.', 2)
      return nil if encoded.to_s.empty? || signature.to_s.empty?
      expected = Base64.urlsafe_encode64(OpenSSL::HMAC.digest('SHA256', secret, encoded), padding: false)
      return nil unless secure_compare(expected, signature)

      payload = JSON.parse(Base64.urlsafe_decode64(encoded))
      return nil if payload['exp'].to_i <= Time.now.to_i

      find(payload['sub'])
    rescue ArgumentError, JSON::ParserError
      nil
    end

    def self.secret
      ENV.fetch('SESSION_SECRET')
    end

    def self.secure_compare(left, right)
      return false unless left.bytesize == right.bytesize
      left.bytes.zip(right.bytes).reduce(0) { |result, pair| result | (pair[0] ^ pair[1]) }.zero?
    end
  end
end
