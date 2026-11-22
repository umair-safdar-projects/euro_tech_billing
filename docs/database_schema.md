# Database schema

The SQLite file lives in the operating system's application-support directory. `PRAGMA foreign_keys = ON` is applied for every connection. Schema changes are applied through ordered version checks in `AppDatabase`, never destructive resets. Current schema version: **4**.

## Tables

| Table | Purpose | Important rules |
|---|---|---|
| `company_settings` | Editable business identity | Singleton row (`id = 1`) |
| `products` | Services and prices | Optional unique seed key; nullable price only for custom-rate services; soft activation |
| `customers` | Customer directory | Required non-empty name; optional idempotency token |
| `invoices` | Invoice headers | Unique number and idempotency token; non-negative minor units; constrained status and totals |
| `invoice_items` | Immutable billed descriptions/rates | Positive whole quantity; checked line total; product may be null |
| `payments` | Immutable invoice receipts | Positive amount; constrained method; unique non-null submission token |
| `audit_logs` | Appendable change history | Entity/action metadata and UTC timestamp |
| `app_settings` | General key/value configuration | Unique key |
| `backup_history` | Recent successful backup audit | Path, size, type, integrity result, and timestamp |

Indexes cover customer names and phones, invoice number/customer/date, invoice-item relationships, payment invoice/date, audit entity lookups, and unique non-null submission tokens.

## Version 2 migration

The forward migration adds nullable `save_token` columns and unique partial indexes to customers and invoices, customer-phone and invoice-number search indexes, and initializes `app_settings.invoice_sequence`. Existing rows remain unchanged. The sequence is initialized from the largest valid existing `ET-` number, so upgrades cannot reuse an allocated number.

## Version 3 migration

The forward migration adds a nullable payment `save_token`, a unique partial token index, and payment-method index. Insert triggers accept only `cash`, `bank_transfer`, or `other`; require an issued positive-value invoice; and reject amounts above the live outstanding balance. Update and delete triggers make payment history immutable. The payment summary view is recreated without touching financial tables and clamps legacy outstanding values to zero.

## Version 4 migration

The forward migration adds nullable company and customer identity snapshot columns to `invoices`, plus `backup_history`. Existing invoice rows remain null and are not backfilled. A null company snapshot is the explicit legacy marker; legacy reprints fall back to current customer/company records and are documented as such. Every newly created invoice stores company name, address, owner/contact details and customer name, phone, and address inside its existing atomic creation transaction.

## Invoice numbering and transactions

The sequence value is advanced inside the same SQLite transaction that inserts the invoice header, snapshot items, and `created` audit event. Opening the editor does not allocate a number. A rollback also rolls back sequence advancement. Invoice numbers are never based on row counts.

## Payment status

`invoice_payment_summary` derives `unpaid`, `partially_paid`, `paid`, or `void` from recorded payments and the invoice total. Payment state is not duplicated in a mutable column. The view also exposes paid and balance minor units.

The no-payment branch is checked before comparing paid and total values. Therefore a zero-value invoice with no payment remains `unpaid`; it is not incorrectly shown as paid.

Payment creation recalculates balance inside the write transaction and is also protected by database triggers. Full and partial receipts transition the derived status naturally; no independent payment-status column exists.

Historical payment rows are protected by update/delete triggers. Operators cannot edit or delete them directly. Reversal and correction remain out of scope until an auditable compensating-entry design is implemented.

## Seed behavior

Seven initial services use stable `seed_key` values and `INSERT ... IGNORE`. Seeding may safely run again: it fills missing canonical rows but never updates an existing operator price or activation choice. Company defaults use the singleton primary key with the same behavior.
