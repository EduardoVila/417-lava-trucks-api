# frozen_string_literal: true

require 'sqlite3'
require 'pg'
require 'fileutils'
require 'monitor'
require_relative 'migrations'

module LavaTrucks
  module Database
    LOCK = Monitor.new

    def self.connection
      @connection ||= begin
        if ENV['DATABASE_URL']
          db = PostgresAdapter.new(PG.connect(ENV['DATABASE_URL'], connect_timeout: 10, sslmode: ENV.fetch('PGSSLMODE', 'require')))
          db.execute_batch(File.read(File.expand_path('schema.pg.sql', __dir__)))
          # Keep existing PostgreSQL databases compatible with newer columns.
          db.execute('ALTER TABLE users ADD COLUMN IF NOT EXISTS tour_completed TEXT NOT NULL DEFAULT \'\'')
          db
        else
        path = ENV.fetch('DATABASE_PATH', File.expand_path('../data/lava.db', __dir__))
        FileUtils.mkdir_p(File.dirname(path)) unless path == ':memory:'
        db = SQLite3::Database.new(path)
        db.results_as_hash = true
        db.busy_timeout = 5000
        db.execute('PRAGMA journal_mode = WAL')
        db.execute_batch(File.read(File.expand_path('schema.sql', __dir__)))
        Migrations.run(db)
        db
        end
      end
    end

    class PostgresAdapter
      def initialize(connection)
        @connection = connection
        @database_url = ENV.fetch('DATABASE_URL')
        @sslmode = ENV.fetch('PGSSLMODE', 'require')
        configure_type_map
        @last_id = nil
      end

      def configure_type_map
        @connection.type_map_for_results = PG::BasicTypeMapForResults.new(@connection)
      end
      def execute_batch(sql)
        sql.split(';').map(&:strip).reject(&:empty?).each { |statement| execute(statement) }
      end
      def execute(sql, binds = [])
        query = sql.gsub('?').with_index { |_match, index| "$#{index + 1}" }
        result = @connection.exec_params(query, binds)
        @last_id = result[0]['id'].to_i if result.ntuples.positive? && result.fields.include?('id')
        result.map { |row| row.transform_keys(&:to_s) }
      rescue PG::ConnectionBad, PG::UnableToSend
        reconnect!
        result = @connection.exec_params(query, binds)
        @last_id = result[0]['id'].to_i if result.ntuples.positive? && result.fields.include?('id')
        result.map { |row| row.transform_keys(&:to_s) }
      end
      def get_first_row(sql, binds = []) = execute(sql, binds).first
      def get_first_value(sql, binds = []) = get_first_row(sql, binds)&.values&.first
      def last_insert_row_id = @last_id

      private

      def reconnect!
        @connection&.close rescue nil
        @connection = PG.connect(@database_url, connect_timeout: 10, sslmode: @sslmode)
        configure_type_map
      end
    end

    def self.synchronize(&)
      LOCK.synchronize(&)
    end

    def self.reset!
      raise 'Test only' unless ENV['APP_ENV'] == 'test'

      connection.execute('DELETE FROM washes')
      connection.execute('DELETE FROM expenses')
      connection.execute('DELETE FROM customers')
      connection.execute("DELETE FROM service_types WHERE code NOT IN ('normal', 'hot')")
    end
  end
end
