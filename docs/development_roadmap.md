# Development roadmap

## 1. Foundation and database — complete

Desktop application shell, GetX architecture, versioned SQLite schema, editable company settings, product/service management, offline storage, and foundational automated tests.

## 2. Invoice creation and history — complete

Customer management, keyboard-first invoice entry, transactional/idempotent writes, durable sequential numbering, immutable item snapshots, pagination, filters, customer history, and read-only invoice details. Audited correction and void workflows remain intentionally deferred.

## 3. Credit and payment management — complete

Transactional full/partial receipts, atomic initial payments, customer ledgers, outstanding balances, credit dashboards, real operational metrics, idempotency, and database overpayment protection. Payment reversals remain deferred to a future controlled correction workflow.

## 4. A5 invoice printing — complete

Professional ISO A5 PDF layout, saved company branding, print preview, system printer selection, PDF export, A4 actual-size placement, payment-aware reprints, and automatic long-invoice pagination. Physical Windows printer validation remains a deployment requirement.

## 5. Reports, backups, testing, and Windows deployment — implementation complete

Operational and financial reports, consistent database backup/restore, identity snapshots, expanded integration tests, branded release packaging, upgrade validation, and deployment guidance are implemented. Final sign-off is blocked only by running the Windows release script, installing the resulting package on the shop computer, and completing physical A4-printer validation.
