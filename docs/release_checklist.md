# Release checklist

## Automated gates

- [ ] `dart format lib test tool` produces no changes.
- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test` passes, including backup/restore and PDF tests.
- [ ] `flutter build windows --release --build-name 1.0.2 --build-number 3` succeeds on Windows.
- [ ] The release bundle contains the executable, Flutter runtime, `app.so`, assets, and SQLite runtime.
- [ ] Inno Setup creates `dist\EuroTechBilling-Setup-1.0.2.exe`.
- [ ] Installer and executable version metadata, name, and icon are correct.

## Upgrade and data safety

- [ ] Install over a copy of the previous release with realistic invoices and payments.
- [ ] Confirm schema v4 migration preserves rows, sequence, product changes, and immutable payments.
- [ ] Create, verify, and restore a manual backup.
- [ ] Force an invalid restore and confirm active data remains available.
- [ ] Confirm uninstall leaves application data and external backups intact.
- [ ] Reinstall and confirm preserved data opens normally.

## 1366 × 768 and scaling

- [ ] Test every screen at 1366 × 768, 100%, 125%, and 150% Windows scaling.
- [ ] Confirm sidebar, dialogs, date pickers, long names, long descriptions, tables, and empty states remain usable.
- [ ] Confirm Tab/Shift+Tab order and Enter/Escape behavior during invoice and payment entry.
- [ ] Test invoice history and customer search with a large copied dataset.

## Physical printer sign-off

- [ ] Windows discovers the shop's A4 printer.
- [ ] An A5 PDF previews at 148 × 210 mm.
- [ ] A5 content prints on A4 centered at 100%/Actual Size.
- [ ] Top-left placement prints without clipping.
- [ ] No driver “Fit”, shrink, or enlargement is active.
- [ ] Typography, totals, and contact details are readable.
- [ ] A multi-page invoice repeats headers and prints every page.
- [ ] Cancelling does not submit a job or alter data.
- [ ] Printer-unavailable behavior is understandable.
- [ ] A paid invoice reprints with current received/balance values.

Production sign-off is blocked until the Windows build, installer upgrade/uninstall checks, and physical printer checklist have evidence recorded by the deployer.
