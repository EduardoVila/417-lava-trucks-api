CREATE TABLE customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plate TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO customers (plate, name)
SELECT plate, MAX(customer) FROM washes GROUP BY plate;
CREATE TABLE washes_customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER NOT NULL REFERENCES customers(id),
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
INSERT INTO washes_customers
  (id, customer_id, date, time, customer, plate, service, service_name,
   amount_cents, stage, paid, paid_on, payment_method, notes, created_at)
SELECT w.id, c.id, w.date, w.time, c.name, w.plate, w.service, w.service_name,
  w.amount_cents, w.stage, w.paid, w.paid_on, w.payment_method, w.notes, w.created_at
FROM washes w JOIN customers c ON c.plate = w.plate;
DROP TABLE washes;
ALTER TABLE washes_customers RENAME TO washes;
CREATE INDEX washes_date ON washes(date);
CREATE INDEX washes_paid_on ON washes(paid_on);
CREATE INDEX washes_customer_id ON washes(customer_id);
