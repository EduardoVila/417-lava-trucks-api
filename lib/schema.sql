CREATE TABLE IF NOT EXISTS service_types (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  default_cents INTEGER CHECK(default_cents IS NULL OR default_cents > 0),
  active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0, 1))
);
INSERT OR IGNORE INTO service_types (code, name) VALUES ('normal', 'Lavação normal'), ('hot', 'Lavação a quente');
CREATE TABLE IF NOT EXISTS customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT, plate TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE COLLATE NOCASE,
  password_digest TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'operator' CHECK(role IN ('admin', 'operator')),
  active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0, 1)),
  tour_completed TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS washes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER REFERENCES customers(id),
  user_id INTEGER REFERENCES users(id),
  date TEXT NOT NULL,
  time TEXT NOT NULL,
  customer TEXT NOT NULL,
  plate TEXT NOT NULL,
  service TEXT NOT NULL REFERENCES service_types(code),
  service_name TEXT NOT NULL DEFAULT 'Lavação normal',
  amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
  stage TEXT NOT NULL CHECK(stage IN ('waiting', 'washing', 'done')),
  paid INTEGER NOT NULL DEFAULT 0 CHECK(paid IN (0, 1)),
  paid_on TEXT,
  payment_method TEXT,
  notes TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK((paid = 0 AND paid_on IS NULL AND payment_method IS NULL)
     OR (paid = 1 AND paid_on IS NOT NULL AND payment_method IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS washes_date ON washes(date);
CREATE INDEX IF NOT EXISTS washes_paid_on ON washes(paid_on);
CREATE TABLE IF NOT EXISTS expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
  payment_method TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS expenses_date ON expenses(date);
