# Architecture

## Principles

Euro Tech Billing is a local-first desktop application. Flutter owns presentation, GetX supplies composition and reactive screen state, repositories isolate SQLite, and domain models carry typed business data. No screen issues SQL directly.

## Layout

```text
lib/
  app/                 application, binding, route, and theme
  core/                database, constants, utilities, shared widgets
  features/
    <feature>/
      domain/          feature models and rules
      data/            repository implementations
      presentation/    controllers, screens, and widgets
```

`InitialBinding` owns dependency wiring. `AppDatabase` owns the connection lifecycle, path selection, configuration, and migrations. Repositories receive that database dependency and expose focused operations to GetX controllers.

## Error and lifecycle behavior

Database startup is awaited before the normal shell is rendered. A failure produces a readable recovery screen and is also reported through Flutter's error pipeline. Repository failures are surfaced in their screen or through a snackbar. Controllers dispose their text controllers; the database exposes an explicit `close` method for tests and controlled shutdowns.

## Financial rules

All money is parsed and calculated as integer paisa (minor units); financial arithmetic never uses floating point. Quantities are positive whole pieces. `InvoiceCalculator` is the shared validation/calculation boundary used before persistence and by the editor. Database checks independently protect totals.

## Invoice lifecycle

The editor has no permanent invoice number. On save, `InvoiceRepository` validates the saved customer and lines, enters one SQLite transaction, checks the idempotency token, advances the durable sequence, inserts the invoice and snapshot items, writes an audit event, and commits. Any error rolls back the number, header, items, and audit event together. Saved invoices are read-only in Milestone 2.

Customer and invoice create operations carry stable per-form submission tokens. Unique partial indexes make repeated clicks or retried repository calls return the original record rather than create duplicates.

History is queried page-by-page with SQL search/date/customer filters. Details read description, unit, quantity, and rate from `invoice_items`; catalogue changes therefore cannot rewrite history.

## Payment lifecycle

`PaymentRepository` validates a stable submission token, reads the current derived invoice balance inside a financial transaction, inserts the immutable payment, and writes its audit event. Schema triggers independently validate the method, invoice eligibility, and live outstanding balance. Unique tokens make retries return the original receipt.

Initial payments use the same repository operation inside the invoice transaction. A failed initial receipt therefore rolls back the invoice number, header, items, invoice audit, payment, and payment audit together. Pay Later and partial-payment invoices require a saved customer; a fully paid invoice may use the explicit Walk-in Customer identity.

Payment rows cannot be updated or deleted. Corrections/reversals are deferred until a safe compensating-entry workflow is specified.

## Credit and reporting queries

Outstanding credit is the sum of nonnegative derived balances for issued invoices. Customer ledgers aggregate original invoice totals, recorded receipts, and remaining amounts without duplicating mutable status. Dashboard sales use invoice issue dates; collections use payment dates, so a receipt today against an older invoice correctly appears only in today's collections.

`ReportRepository` applies half-open date ranges to invoice issue dates and payment dates independently. It returns invoiced sales, actual collections, current outstanding credit, status groups, top customers, and product/service summaries. CSV and PDF formatting are isolated in `ReportExportService` and never mutate business data.

## Backup and restore

`BackupService` uses SQLite `VACUUM INTO`, which creates a transactionally consistent standalone snapshot without copying an active WAL database. Every candidate is opened read-only, checked with `PRAGMA integrity_check`, checked for required Euro Tech tables, and checked against the supported schema range.

Restore first creates an external safety backup, stages the selected file, closes SQLite, swaps files, runs forward migrations, reopens, and validates. Any error attempts rollback to the original file; the safety backup is retained. After success, active controllers reload from the reopened database.

## Printing architecture

Printing is split into four boundaries. `InvoicePrintDataService` performs read-only retrieval of saved invoice snapshots, current payment summary, current company settings, and printing preferences. `InvoicePrintModel` is an immutable document view model. `InvoicePdfService` owns PDF layout and pagination. `InvoicePrintingService` coordinates the platform print dialog and user-selected export path.

PDF generation never opens a write transaction and does not create invoice, payment, or audit rows. A reprint retains saved item descriptions, quantities, unit rates, discount, total, invoice number, and issue date while labelling the current received amount and balance with a generation timestamp.

Schema v4 snapshots company and customer identity during the same transaction that creates each new invoice. Reprints prefer these issuance-time fields while retaining live payment balances. Older rows deliberately keep null snapshot columns and use the documented current-record fallback; migration never fabricates historical identity.
