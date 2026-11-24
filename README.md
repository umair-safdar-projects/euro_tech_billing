# Euro Tech Billing System

Offline-first Windows desktop billing software for **Euro Tech Edging and Cutting**. Milestones 1–5 provide billing and credit workflows, reporting, verified backup/restore, historical invoice identity, and professional A5 printing.

## Requirements

- Flutter 3.38 or a compatible stable release (Dart 3.11+)
- Windows 10/11 and Visual Studio Desktop development with C++ for Windows builds

## Run locally

```bash
flutter pub get
flutter run -d windows
```

The application is fully offline. Its database is stored under the platform application-support directory in an `EuroTechBilling` folder, never beside the installed executable.

## Quality checks

```bash
dart format lib test
flutter analyze
flutter test
flutter build windows
```

On Windows, the reproducible release and Inno Setup package are built with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_windows_release.ps1 -Version 1.0.2 -BuildNumber 3
```

Tests use isolated temporary SQLite databases and do not touch operator data.

## Current scope

- Responsive, persistent navigation shell with named routes and a compact drawer
- Versioned schema, migrations, foreign keys, constraints, indexes, and audit-ready tables
- Idempotent product seeds that preserve operator changes
- Persistent, validated company settings
- Product price editing, custom services, and activation/deactivation
- Searchable customer management with details and customer invoice history
- Keyboard-friendly invoice entry with catalogue and custom lines
- Exact integer-minor-unit calculations and fixed discounts
- Atomic sequential invoice numbering (`ET-000001`)
- Transactional, idempotent invoice persistence with immutable item snapshots
- Paginated invoice history, date/search filters, and read-only invoice details
- Full and partial cash, bank-transfer, and other payment recording
- Atomic initial payments during invoice creation, including fully paid walk-in invoices
- Customer ledgers, outstanding-customer search, and credit overview
- Live dashboard separation of invoiced sales, collected payments, and outstanding credit
- Immutable, idempotent payment records with database overpayment protection
- Branded ISO A5 invoice PDFs with automatic multi-page item tables
- Actual-size A5 placement on A4 paper, centered or top-left
- Preview, system printer selection, reprint, and user-selected PDF export
- Persistent printing preferences, footer text, and optional company logo
- Safe SQLite online backups, automatic daily backup, integrity checks, restore recovery, and backup history
- Daily, monthly, and custom-range sales/collection/credit reports with CSV and PDF export
- Company and customer identity snapshots for every newly issued invoice
- Branded Windows executable metadata, icon, and reproducible Inno Setup installer

Payment correction/reversal is intentionally deferred until a controlled audited workflow is designed. Physical printer validation must still be completed on the target Windows shop hardware.

See [architecture](docs/architecture.md), [database schema](docs/database_schema.md), and [development roadmap](docs/development_roadmap.md). Operator workflows are in the [operator guide](docs/operator_guide.md); deployment is covered by [Windows installation](docs/windows_installation.md) and the [release checklist](docs/release_checklist.md). Backup behavior is documented in [backup and restore](docs/backup_restore.md), and printing checks are in [invoice printing](docs/invoice_printing.md).
