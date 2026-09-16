ENV['RACK_ENV'] = 'production'
ENV['APP_ENV'] = 'production'
abort 'Use uma base PostgreSQL descartável e CONFIRM_DISPOSABLE_DATABASE=1' unless ENV['CONFIRM_DISPOSABLE_DATABASE'] == '1'
ENV['DATABASE_URL'] = ENV.fetch('TEST_DATABASE_URL')
ENV['PGSSLMODE'] = 'disable'
ENV['SESSION_SECRET'] = 'x' * 64
ENV['ALLOWED_ORIGINS'] = 'https://test.web.app'
ENV['ALLOWED_HOSTS'] = 'example.org'
require 'rack/test'
require_relative '../app'
include Rack::Test::Methods
def app = LavaTrucks::App
def check(code)
  raise "Expected #{code}, got #{last_response.status}: #{last_response.body}" unless last_response.status == code
end
LavaTrucks::Database.connection.execute("INSERT INTO users (name, username, password_digest, role) VALUES (?, ?, ?, ?) ON CONFLICT(username) DO NOTHING", ['Admin', 'deploytest', BCrypt::Password.create('test-password'), 'admin'])
header 'Origin', 'https://test.web.app'
options '/api/me', {}, { 'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'GET' }
check(204)
raise 'cors' unless last_response.headers['access-control-allow-origin'] == 'https://test.web.app'
get '/api/me'; check(401)
post 'https://example.org/api/login', {username: 'deploytest', password: 'test-password'}; check(200)
raise 'cookie' unless last_response.headers['set-cookie'].to_s.include?('secure')
# Secure session requests use HTTPS, as they do behind the Render proxy.
def https_get(path)
 get "https://example.org#{path}"
end
https_get '/api/me'; check(200)
post 'https://example.org/api/users', {name:'Worker', username:"worker#{Time.now.to_i}", password:'worker-password'}; check(201)
raise 'id type' unless JSON.parse(last_response.body)['data']['id'].is_a?(Integer)
header 'Content-Type', 'application/json'
post 'https://example.org/api/washes', JSON.generate(date:'2026-09-15', time:'09:00', customer:'Test',plate:'ABC1D23',service:'normal',amount_cents:10000,stage:'waiting',paid:false,notes:''); check(201)
https_get '/api/summary?from=2026-09-01&to=2026-09-30'; check(200)
https_get '/api/user-metrics'; check(200)
post 'https://example.org/api/me/tour', JSON.generate(page:'team'); check(200)
https_get '/api/me'; check(200)
raise 'tour' unless JSON.parse(last_response.body)['data']['tour_completed'].include?('team')
header 'Origin', 'https://evil.example'
post 'https://example.org/api/login', ''; check(403)
puts 'PASS: PostgreSQL login, secure cookies, CORS preflight, unauthorized access, create user/service, summary, metrics and tour persistence'
