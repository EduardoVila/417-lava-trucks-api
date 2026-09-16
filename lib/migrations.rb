# frozen_string_literal: true

module LavaTrucks
  module Migrations
  def self.run(db)
    version = db.get_first_value('PRAGMA user_version')
    columns = db.execute('PRAGMA table_info(washes)').map { |row| row['name'] }
    tables = db.execute("SELECT name FROM sqlite_master WHERE type = 'table'").map { |row| row['name'] }
    if version.zero? && columns.include?('customer_id')
      db.execute('CREATE INDEX IF NOT EXISTS washes_customer_id ON washes(customer_id)')
      version = 2
    end

    # A database created by an earlier boot may have completed the first
    # migration before SQLite raised an error on the later customer index.
    # Recognize that partially versioned state and continue with migration 2.
    if version.zero? && tables.include?('service_types')
      db.execute('PRAGMA user_version = 1')
      version = 1
    end
      if version < 1
        db.execute_batch(File.read(File.expand_path('migrations/001_service_types.sql', __dir__)))
        db.execute('PRAGMA user_version = 1')
      end
    return ensure_users(db) if version >= 2

    db.execute_batch(File.read(File.expand_path('migrations/002_customers.sql', __dir__)))
    db.execute('CREATE INDEX IF NOT EXISTS washes_customer_id ON washes(customer_id)')
    db.execute('PRAGMA user_version = 2')
    ensure_users(db)
  end

  def self.ensure_users(db)
    columns = db.execute('PRAGMA table_info(washes)').map { |row| row['name'] }
    db.execute('ALTER TABLE washes ADD COLUMN user_id INTEGER REFERENCES users(id)') unless columns.include?('user_id')
    user_columns = db.execute('PRAGMA table_info(users)').map { |row| row['name'] }
    db.execute("ALTER TABLE users ADD COLUMN tour_completed TEXT NOT NULL DEFAULT ''") unless user_columns.include?('tour_completed')
    db.execute('PRAGMA user_version = 3')
  end
  end
end
