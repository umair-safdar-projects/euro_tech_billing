# Euro Tech Billing operator guide

## Daily start

Launch **Euro Tech Billing** from the desktop or Start menu. Check the Dashboard and the backup status in Settings. If a backup warning appears, fix the folder or create a manual backup before entering more work.

## Create an invoice

1. Choose **New Invoice**.
2. Select or create a customer. A saved customer is required for credit and partial-payment invoices.
3. Add catalogue services or a custom line, then confirm quantity and price.
4. Enter any fixed discount.
5. Choose Pay Later, partial initial payment, or full payment.
6. Save once. Repeated clicks are protected by the submission token.
7. Use the success notification to preview and print.

Invoice numbers are allocated only at successful save and cannot be reused. Calculations use integer paisa, and item/company/customer identity is preserved for newly created invoices.

## Record a later payment

Open **Payments / Credit**, locate the outstanding invoice, and enter the amount, method, and actual payment date. The amount cannot exceed the live balance. Saved payments are immutable and cannot be edited or deleted. Payment correction/reversal is not available; contact the system maintainer rather than changing the database.

## Reprint an invoice

Open **Invoice History**, search by number/customer/date, and select Preview. A reprint keeps invoice identity and item snapshots, but paid amount and remaining balance are current and labelled “Balance as of.” Legacy invoices created before schema v4 use current customer/company identity as an explicit fallback.

## Reports

Open **Reports** and choose Daily, Monthly, or a custom date range. Invoiced sales follow invoice issue date. Collections follow the actual payment date. Current outstanding credit is shown separately. Use **Export CSV** for spreadsheet analysis or **Export PDF** for a shareable summary.

## Backup and restore

Use **Settings → Backup and restore**. Choose a durable folder, verify a recent success, and use **Back up now** before updates or major corrections. Restore replaces active data only after metadata review and a safety backup. See [backup and restore](backup_restore.md) for the complete process.

## Printing troubleshooting

- Confirm the Windows printer is installed and visible in system settings.
- For A5 content on A4, select A4 media and 100% or Actual Size—not Fit.
- Try both centered and top-left placement in Printing Settings.
- If no printer is available, export the PDF and print it from a trusted PDF viewer.
- A corrupt logo falls back to text branding; choose a valid PNG/JPEG in Settings.
- Cancelling the print dialog never changes the invoice or payment.
