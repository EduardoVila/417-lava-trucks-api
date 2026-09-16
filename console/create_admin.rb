# frozen_string_literal: true

require_relative '../lib/database'
require 'bcrypt'

name = ENV.fetch('ADMIN_NAME') { abort 'Informe ADMIN_NAME.' }
username = ENV.fetch('ADMIN_USERNAME') { abort 'Informe ADMIN_USERNAME.' }
password = ENV.fetch('ADMIN_PASSWORD') { abort 'Informe ADMIN_PASSWORD.' }
abort 'A senha precisa ter ao menos 8 caracteres.' if password.length < 8

LavaTrucks::Database.connection.execute(
  'INSERT INTO users (name, username, password_digest, role) VALUES (?, ?, ?, ?)',
  [name, username, BCrypt::Password.create(password), 'admin']
)
puts "Administrador #{username} criado."
