abstract final class DatabaseSchema {
  static const currentVersion = 4;

  static const createStatements = <String>[
    '''CREATE TABLE company_settings (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      company_name TEXT NOT NULL CHECK (length(trim(company_name)) > 0),
      owner_name TEXT NOT NULL DEFAULT '', primary_phone TEXT NOT NULL DEFAULT '',
      secondary_phone TEXT NOT NULL DEFAULT '', additional_contact_name TEXT NOT NULL DEFAULT '',
      additional_contact_phone TEXT NOT NULL DEFAULT '', email TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '', logo_path TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
    '''CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT, seed_key TEXT UNIQUE,
      name TEXT NOT NULL CHECK (length(trim(name)) > 0), description TEXT NOT NULL DEFAULT '',
      unit TEXT NOT NULL CHECK (length(trim(unit)) > 0),
      default_price_minor INTEGER CHECK (default_price_minor IS NULL OR default_price_minor >= 0),
      requires_custom_price INTEGER NOT NULL DEFAULT 0 CHECK (requires_custom_price IN (0, 1)),
      is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      CHECK (requires_custom_price = 0 OR default_price_minor IS NULL))''',
    '''CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL CHECK (length(trim(name)) > 0), phone TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
    '''CREATE TABLE invoices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_number TEXT NOT NULL UNIQUE CHECK (length(trim(invoice_number)) > 0),
      customer_id INTEGER REFERENCES customers(id) ON UPDATE CASCADE ON DELETE RESTRICT,
      issue_date TEXT NOT NULL, subtotal_minor INTEGER NOT NULL CHECK (subtotal_minor >= 0),
      discount_minor INTEGER NOT NULL DEFAULT 0 CHECK (discount_minor >= 0),
      grand_total_minor INTEGER NOT NULL CHECK (grand_total_minor >= 0),
      status TEXT NOT NULL DEFAULT 'issued' CHECK (status IN ('draft', 'issued', 'void')),
      notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      CHECK (discount_minor <= subtotal_minor),
      CHECK (grand_total_minor = subtotal_minor - discount_minor))''',
    '''CREATE TABLE invoice_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON UPDATE CASCADE ON DELETE CASCADE,
      product_id INTEGER REFERENCES products(id) ON UPDATE CASCADE ON DELETE RESTRICT,
      description_snapshot TEXT NOT NULL CHECK (length(trim(description_snapshot)) > 0),
      quantity INTEGER NOT NULL CHECK (quantity > 0),
      unit TEXT NOT NULL CHECK (length(trim(unit)) > 0),
      unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
      line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0),
      CHECK (line_total_minor = quantity * unit_price_minor))''',
    '''CREATE TABLE payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON UPDATE CASCADE ON DELETE RESTRICT,
      amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
      payment_method TEXT NOT NULL CHECK (length(trim(payment_method)) > 0),
      payment_date TEXT NOT NULL, reference TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
    '''CREATE TABLE audit_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity_type TEXT NOT NULL CHECK (length(trim(entity_type)) > 0), entity_id INTEGER,
      action TEXT NOT NULL CHECK (length(trim(action)) > 0), metadata TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL)''',
    '''CREATE TABLE app_settings (
      key TEXT PRIMARY KEY CHECK (length(trim(key)) > 0), value TEXT NOT NULL,
      updated_at TEXT NOT NULL) WITHOUT ROWID''',
    'CREATE INDEX idx_customers_name ON customers(name)',
    'CREATE INDEX idx_invoices_customer_id ON invoices(customer_id)',
    'CREATE INDEX idx_invoices_issue_date ON invoices(issue_date)',
    'CREATE INDEX idx_invoice_items_invoice_id ON invoice_items(invoice_id)',
    'CREATE INDEX idx_invoice_items_product_id ON invoice_items(product_id)',
    'CREATE INDEX idx_payments_invoice_id ON payments(invoice_id)',
    'CREATE INDEX idx_payments_payment_date ON payments(payment_date)',
    'CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id)',
    '''CREATE VIEW invoice_payment_summary AS
      SELECT i.id AS invoice_id, i.grand_total_minor,
      COALESCE(SUM(p.amount_minor), 0) AS paid_minor,
      i.grand_total_minor - COALESCE(SUM(p.amount_minor), 0) AS balance_minor,
      CASE WHEN i.status = 'void' THEN 'void'
        WHEN COALESCE(SUM(p.amount_minor), 0) <= 0 THEN 'unpaid'
        WHEN COALESCE(SUM(p.amount_minor), 0) < i.grand_total_minor THEN 'partially_paid'
        ELSE 'paid' END AS payment_status
      FROM invoices i LEFT JOIN payments p ON p.invoice_id = i.id GROUP BY i.id''',
  ];

  static const migration2Statements = <String>[
    'ALTER TABLE customers ADD COLUMN save_token TEXT',
    'CREATE UNIQUE INDEX idx_customers_save_token ON customers(save_token) WHERE save_token IS NOT NULL',
    'CREATE INDEX idx_customers_phone ON customers(phone)',
    'ALTER TABLE invoices ADD COLUMN save_token TEXT',
    'CREATE UNIQUE INDEX idx_invoices_save_token ON invoices(save_token) WHERE save_token IS NOT NULL',
    'CREATE INDEX idx_invoices_number_search ON invoices(invoice_number)',
  ];

  static const migration3Statements = <String>[
    'ALTER TABLE payments ADD COLUMN save_token TEXT',
    'CREATE UNIQUE INDEX idx_payments_save_token ON payments(save_token) WHERE save_token IS NOT NULL',
    'CREATE INDEX idx_payments_method ON payments(payment_method)',
    '''CREATE TRIGGER payments_validate_insert BEFORE INSERT ON payments
      BEGIN
        SELECT CASE WHEN NEW.payment_method NOT IN ('cash', 'bank_transfer', 'other')
          THEN RAISE(ABORT, 'invalid payment method') END;
        SELECT CASE WHEN NOT EXISTS (
          SELECT 1 FROM invoices i WHERE i.id = NEW.invoice_id
          AND i.status = 'issued' AND i.grand_total_minor > 0)
          THEN RAISE(ABORT, 'invoice is not eligible for payment') END;
        SELECT CASE WHEN NEW.amount_minor > (
          SELECT i.grand_total_minor - COALESCE(SUM(p.amount_minor), 0)
          FROM invoices i LEFT JOIN payments p ON p.invoice_id = i.id
          WHERE i.id = NEW.invoice_id GROUP BY i.id)
          THEN RAISE(ABORT, 'payment exceeds outstanding balance') END;
      END''',
    '''CREATE TRIGGER payments_immutable_update BEFORE UPDATE ON payments
      BEGIN SELECT RAISE(ABORT, 'payments are immutable'); END''',
    '''CREATE TRIGGER payments_immutable_delete BEFORE DELETE ON payments
      BEGIN SELECT RAISE(ABORT, 'payments are immutable'); END''',
    'DROP VIEW invoice_payment_summary',
    '''CREATE VIEW invoice_payment_summary AS
      SELECT i.id AS invoice_id, i.grand_total_minor,
      COALESCE(SUM(p.amount_minor), 0) AS paid_minor,
      MAX(i.grand_total_minor - COALESCE(SUM(p.amount_minor), 0), 0) AS balance_minor,
      CASE WHEN i.status = 'void' THEN 'void'
        WHEN COALESCE(SUM(p.amount_minor), 0) <= 0 THEN 'unpaid'
        WHEN COALESCE(SUM(p.amount_minor), 0) < i.grand_total_minor THEN 'partially_paid'
        ELSE 'paid' END AS payment_status
      FROM invoices i LEFT JOIN payments p ON p.invoice_id = i.id GROUP BY i.id''',
  ];

  static const migration4Statements = <String>[
    'ALTER TABLE invoices ADD COLUMN company_name_snapshot TEXT',
    'ALTER TABLE invoices ADD COLUMN company_address_snapshot TEXT',
    'ALTER TABLE invoices ADD COLUMN company_owner_snapshot TEXT',
    'ALTER TABLE invoices ADD COLUMN company_primary_phone_snapshot TEXT',
    'ALTER TABLE invoices ADD COLUMN company_secondary_phone_snapshot TEXT',
    'ALTER TABLE invoices ADD COLUMN company_contact_name_snapshot TEXT',
    'ALTER TABLE invoices ADD COLUMN company_contact_phone_snapshot TEXT',
    'ALTER TABLE invoices ADD COLUMN company_email_snapshot TEXT',
    'ALTER TABLE invoices ADD COLUMN customer_name_snapshot TEXT',
    'ALTER TABLE invoices ADD COLUMN customer_phone_snapshot TEXT',
    'ALTER TABLE invoices ADD COLUMN customer_address_snapshot TEXT',
    '''CREATE TABLE backup_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      file_path TEXT NOT NULL, created_at TEXT NOT NULL,
      file_size INTEGER NOT NULL CHECK (file_size >= 0),
      backup_type TEXT NOT NULL CHECK (backup_type IN ('manual', 'automatic', 'safety')),
      integrity_status TEXT NOT NULL DEFAULT 'ok')''',
    'CREATE INDEX idx_backup_history_created_at ON backup_history(created_at DESC)',
  ];
}
