CREATE TABLE service_types (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  default_cents INTEGER CHECK(default_cents IS NULL OR default_cents > 0),
  active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0, 1))
);
INSERT INTO service_types (code, name) VALUES
  ('normal', 'Lavação normal'), ('hot', 'Lavação a quente');

-- Rebuild the old constrained service column atomically, retaining every row,
-- identifier, monetary value, payment and timestamp.
CREATE TABLE washes_catalog (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,
  time TEXT NOT NULL,
  customer TEXT NOT NULL,
  plate TEXT NOT NULL,
  service TEXT NOT NULL REFERENCES service_types(code),
  service_name TEXT NOT NULL,
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
INSERT INTO washes_catalog
  (id, date, time, customer, plate, service, service_name, amount_cents,
   stage, paid, paid_on, payment_method, notes, created_at)
SELECT id, date, time, customer, plate, service,
  CASE service WHEN 'normal' THEN 'Lavação normal' ELSE 'Lavação a quente' END,
  amount_cents, stage, paid, paid_on, payment_method, notes, created_at
FROM washes;
DROP TABLE washes;
ALTER TABLE washes_catalog RENAME TO washes;
CREATE INDEX washes_date ON washes(date);
CREATE INDEX washes_paid_on ON washes(paid_on);
