# frozen_string_literal: true

require 'bcrypt'

module LavaTrucks
  module Auth
    SESSION_KEY = 'lava_user_id'

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
  end
end
