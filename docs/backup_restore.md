# Backup and restore

## Daily protection

Open **Settings → Backup and restore** and choose a folder outside the application installation directory. A folder on a second drive or a regularly copied external drive is preferred. Paths containing spaces or non-English characters are supported.

While the application runs, it checks the last successful backup time and creates one automatic backup when at least 24 hours have elapsed. The Settings card shows the destination, last success, health warning, and recent history. **Back up now** creates an immediate manual snapshot. Existing backup files are never overwritten.

Backups are standalone SQLite files made with `VACUUM INTO`. This is a consistent online snapshot; the application never copies an active WAL database file.

## Restore procedure

1. Close invoice-entry work and open **Settings → Backup and restore**.
2. Select **Restore backup** and choose a `.sqlite` or `.db` file.
3. Review its modification time, schema version, and invoice/customer/payment counts.
4. Confirm only when the selected backup is the intended recovery point.
5. The application creates a safety backup of current data, closes SQLite, stages the selected file, migrates older supported schemas, reopens it, and runs a final integrity check.
6. Screens reload from the restored database.

If validation fails, nothing is replaced. If a failure happens after replacement starts, the application attempts to restore the original database and retains the external safety backup. Do not delete safety backups until the restored data has been checked.

## Health and troubleshooting

- A backup is healthy when the last success is less than 48 hours old.
- “Folder is not writable” means Windows permissions or the drive must be corrected.
- A newer-schema backup requires upgrading the application before restore.
- An integrity failure means the file is damaged or is not an Euro Tech backup.
- Low disk space can prevent backup and restore staging. Free space and retry.
- Technical errors are sent to Flutter's diagnostic pipeline; ordinary dialogs avoid exposing customer data or stack traces.
