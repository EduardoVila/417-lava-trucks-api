# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'csv'
require 'rack/session/cookie'
require_relative 'lib/database'
require_relative 'lib/validation'
require_relative 'lib/repository'
require_relative 'lib/summary'
require_relative 'lib/request_helpers'
require_relative 'lib/csv_export'
require_relative 'lib/service_types'
require_relative 'lib/auth'
require_relative 'lib/deployment'

module LavaTrucks
  class App < Sinatra::Base
    set :show_exceptions, false
    set :raise_errors, false
    set :bind, '127.0.0.1'
    set :public_folder, File.expand_path('../web/dist', __dir__)
    set :host_authorization, { permitted_hosts: Deployment::HOSTS }
    set :protection, origin_whitelist: Deployment::ORIGINS
    use Cors
    use Rack::Session::Cookie, key: 'lava_session', secret: ENV.fetch('SESSION_SECRET'),
                              httponly: true, secure: Deployment::PRODUCTION,
                              same_site: Deployment::PRODUCTION ? :none : :lax, expire_after: 604_800

    # One database connection; synchronize complete requests, including receive.
    def call(env)
      Database.synchronize { super }
    end

    before '/api/*' do
      content_type :json
      headers 'Cache-Control' => 'no-store', 'X-Content-Type-Options' => 'nosniff'
      next unless %w[POST PATCH PUT DELETE].include?(request.request_method)
      next if %w[/api/login /api/users].include?(request.path)

      halt 415, JSON.generate(error: 'Envie JSON.') unless request.media_type == 'application/json'
    end

    helpers RequestHelpers

    helpers do
      def current_user
        @current_user ||= Auth.find(session[Auth::SESSION_KEY])
      end
    end

    before '/api/*' do
      next if ENV['APP_ENV'] == 'test' && !Deployment::PRODUCTION
      next if ['/api/health', '/api/login'].include?(request.path)
      halt 401, JSON.generate(error: 'Faça login para continuar.') unless current_user
    end

    get('/api/health') { respond({ status: 'ok' }) }
    post '/api/login' do
      user = Auth.authenticate(params['username'], params['password'])
      halt 401, JSON.generate(error: 'Usuário ou senha inválidos.') unless user
      session[Auth::SESSION_KEY] = user['id']
      respond(Auth.public_user(user))
    end
    post '/api/logout' do
      session.clear
      respond({ logged_out: true })
    end
    get('/api/me') { respond(Auth.public_user(current_user)) }
    patch '/api/me/profile' do
      name = Validation.text(input['name'], 'Nome', max: 120)
      username = Validation.text(input['username'], 'Usuário', max: 40)
      password = input['password'].to_s
      if password.empty?
        Database.connection.execute('UPDATE users SET name = ?, username = ? WHERE id = ?', [name, username, current_user['id']])
      else
        halt 422, JSON.generate(error: 'A senha precisa ter ao menos 8 caracteres.') if password.length < 8
        Database.connection.execute('UPDATE users SET name = ?, username = ?, password_digest = ? WHERE id = ?', [name, username, BCrypt::Password.create(password), current_user['id']])
      end
      respond(Auth.public_user(Database.connection.get_first_row('SELECT id, name, username, role, active, tour_completed FROM users WHERE id = ?', [current_user['id']])))
    end
    post '/api/me/tour' do
      page = Validation.text(input['page'], 'Página', max: 40)
      allowed = %w[dashboard washes receivables expenses customers service-types team]
      halt 422, JSON.generate(error: 'Página de guia inválida.') unless allowed.include?(page)
      completed = current_user['tour_completed'].to_s.split(',').reject(&:empty?) | [page]
      Database.connection.execute('UPDATE users SET tour_completed = ? WHERE id = ?', [completed.join(','), current_user['id']])
      respond({ tour_completed: completed })
    end
    get('/api/users') do
      halt 403, JSON.generate(error: 'Apenas administradores podem gerenciar usuários.') unless current_user['role'] == 'admin'
      respond(Database.connection.execute('SELECT id, name, username, role, active, created_at FROM users ORDER BY name'))
    end
    post '/api/users' do
      halt 403, JSON.generate(error: 'Apenas administradores podem gerenciar usuários.') unless current_user['role'] == 'admin'
      name = Validation.text(params['name'], 'Nome', max: 120)
      username = Validation.text(params['username'], 'Usuário', max: 40)
      password = params['password'].to_s
      halt 422, JSON.generate(error: 'A senha precisa ter ao menos 8 caracteres.') if password.length < 8
      role = params['role'].to_s == 'admin' ? 'admin' : 'operator'
      Database.connection.execute('INSERT INTO users (name, username, password_digest, role) VALUES (?, ?, ?, ?) RETURNING id', [name, username, BCrypt::Password.create(password), role])
      respond(Auth.public_user(Database.connection.get_first_row('SELECT id, name, username, role, active FROM users WHERE id = ?', [Database.connection.last_insert_row_id])), 201)
    end
    patch '/api/users/:id' do
      halt 403, JSON.generate(error: 'Apenas administradores podem gerenciar usuários.') unless current_user['role'] == 'admin'
      target = Database.connection.get_first_row('SELECT * FROM users WHERE id = ?', [params[:id]])
      halt 404, JSON.generate(error: 'Funcionário não encontrado.') unless target
      name = Validation.text(input['name'], 'Nome', max: 120)
      username = Validation.text(input['username'], 'Usuário', max: 40)
      role = input['role'].to_s == 'admin' ? 'admin' : 'operator'
      password = input['password'].to_s
      if password.empty?
        Database.connection.execute('UPDATE users SET name = ?, username = ?, role = ? WHERE id = ?', [name, username, role, target['id']])
      else
        halt 422, JSON.generate(error: 'A senha precisa ter ao menos 8 caracteres.') if password.length < 8
        Database.connection.execute('UPDATE users SET name = ?, username = ?, role = ?, password_digest = ? WHERE id = ?', [name, username, role, BCrypt::Password.create(password), target['id']])
      end
      respond(Auth.public_user(Database.connection.get_first_row('SELECT id, name, username, role, active, tour_completed FROM users WHERE id = ?', [target['id']])))
    end
    delete '/api/users/:id' do
      halt 403, JSON.generate(error: 'Apenas administradores podem gerenciar usuários.') unless current_user['role'] == 'admin'
      halt 422, JSON.generate(error: 'Você não pode excluir o próprio acesso.') if params[:id].to_i == current_user['id'].to_i
      target = Database.connection.get_first_row('SELECT id, active FROM users WHERE id = ?', [params[:id]])
      halt 404, JSON.generate(error: 'Funcionário não encontrado.') unless target && target['active'].to_i == 1
      Database.connection.execute('UPDATE users SET active = 0 WHERE id = ?', [params[:id]])
      respond({ deleted: true })
    end
    get('/api/options') do
      respond({ payment_methods: Validation::METHODS,
                categories: Validation::CATEGORIES,
                service_types: ServiceTypes.all,
                demo: ENV['DEMO_MODE'] == '1' })
    end
    get('/api/washes') { respond(repository.all) }
    get('/api/customers') { respond(Database.connection.execute('SELECT * FROM customers ORDER BY name')) }
    get('/api/service-types') { respond(ServiceTypes.all) }
    get('/api/expenses') { respond(repository('expenses').all) }
    get('/api/summary') { respond(Summary.call(*period)) }

    post '/api/washes' do
      attributes = Validation.wash(input)
      service = ServiceTypes.validate_code(attributes['service'])
      upsert_sql = 'INSERT INTO customers (plate, name, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP) '
      upsert_sql += 'ON CONFLICT(plate) DO UPDATE SET name = excluded.name, updated_at = CURRENT_TIMESTAMP'
      Database.connection.execute(
        upsert_sql,
        [attributes['plate'], attributes['customer']]
      )
      customer_id = Database.connection.get_first_value(
        'SELECT id FROM customers WHERE plate = ?', [attributes['plate']]
      )
      attributes['customer_id'] = customer_id
      attributes['user_id'] = current_user['id']
      attributes['service_name'] = service['name']
      respond(repository.create(attributes), 201)
    end

    patch '/api/washes/:id' do
      current = find!
      attributes = Validation.wash(input)
      if current['paid']
        protected_fields = %w[amount_cents paid_on payment_method]
        changed = protected_fields.any? { |key| attributes[key] != current[key] }
        if changed || attributes['paid'] != 1
          halt 409,
               JSON.generate(error: 'Os dados de uma lavagem recebida não podem ser alterados.')
        end
      elsif attributes['paid'] == 1
        halt 409, JSON.generate(error: 'Use Registrar recebimento para receber esta lavagem.')
      end
      service = ServiceTypes.validate_code(attributes['service'])
      attributes['service_name'] = service['name']
      attributes['user_id'] ||= current_user['id']
      respond(repository.update(params[:id], attributes))
    end

    post '/api/washes/:id/receive' do
      current = find!
      halt 409, JSON.generate(error: 'Esta lavagem já foi recebida.') if current['paid']

      payment = Validation.payment(input, current['date'])
      respond(repository.update(params[:id], payment.merge('paid' => 1)))
    end

    post '/api/expenses' do
      respond(repository('expenses').create(Validation.expense(input)), 201)
    end

    post '/api/service-types' do
      respond(ServiceTypes.create(input), 201)
    end

    patch '/api/service-types/:code' do
      halt 404, JSON.generate(error: 'Tipo de lavagem não encontrado.') unless ServiceTypes.find(params[:code])
      respond(ServiceTypes.update(params[:code], input))
    end

    patch '/api/expenses/:id' do
      repo = repository('expenses')
      find!(repo)
      respond(repo.update(params[:id], Validation.expense(input)))
    end

    get '/api/export/:kind' do
      halt 404, JSON.generate(error: 'Exportação não encontrada.') unless %w[washes expenses].include?(params[:kind])
      rows = repository(params[:kind]).all
      content_type 'text/csv; charset=utf-8'
      attachment "417-#{params[:kind]}.csv"
      CsvExport.call(params[:kind], rows)
    end

    get '/api/user-metrics' do
      rows = Database.connection.execute(<<~SQL, [params['from'] || '0000-01-01', params['to'] || '9999-12-31'])
        SELECT u.id, u.name, u.username, COUNT(w.id) AS count,
               COALESCE(SUM(w.amount_cents), 0) AS amount_cents,
               #{ENV['DATABASE_URL'] ? "STRING_AGG(DISTINCT w.service_name, ',')" : 'GROUP_CONCAT(DISTINCT w.service_name)'} AS services
        FROM users u LEFT JOIN washes w ON w.user_id = u.id AND w.date BETWEEN ? AND ?
        WHERE u.active = 1 GROUP BY u.id ORDER BY count DESC, u.name
      SQL
      respond(rows.map { |row| row.merge('services' => row['services'].to_s.split(',')) })
    end

    get '/' do
      send_file File.join(settings.public_folder, 'index.html')
    end

    error ValidationError do
      status 422
      JSON.generate(error: env['sinatra.error'].message)
    end

    error do
      status 500
      JSON.generate(error: 'Não foi possível concluir. Tente novamente.')
    end

    not_found do
      content_type :json
      JSON.generate(error: 'Recurso não encontrado.')
    end
  end
end
