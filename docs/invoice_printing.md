# Invoice printing

## Document format

The primary document is portrait ISO A5: **148 × 210 mm**. It uses 7 mm internal safe margins, a low-ink navy-and-white design, original saved invoice-item snapshots, and a repeated header and page number on continuation pages. Item tables paginate automatically; totals appear after the final item.

The totals section shows original subtotal, discount, and grand total alongside the current received amount, remaining balance, and derived payment status. Current ledger information is labelled with a “Balance as of” generation timestamp. A zero-value invoice with no receipt remains `UNPAID`.

## A4 paper

The A4 option keeps the logical A5 region at its real physical dimensions. It never scales A5 content to fill A4. The region can be centered or positioned near the top-left with a 5 mm outer safety offset.

Select A4 paper in the system print dialog. Printer-driver scaling should remain at 100% or “actual size”; do not select “fit to page.”

## Preview, printing, and export

Invoice Details provides Preview Invoice, Print Invoice, and Export PDF actions. Invoice History provides a direct preview/reprint shortcut, and the successful save notification offers immediate preview.

Preview uses the `printing` package PDF viewer. Printing opens the operating system workflow so the operator can select an installed printer; the application never silently sends a job. Cancelling does not change invoice or payment data. Export opens a native save-location chooser and writes to the selected path.

## Settings

Settings → Printing Settings stores the default paper, A4 placement, footer message, and preview-before-printing preference in `app_settings`. The company logo path is stored with company settings. Missing, unreadable, or corrupt images fall back to text branding without preventing generation.

## Historical behavior

Invoice number, issue date, items, quantities, prices, discount, and grand total come from saved invoice and item snapshots. Payment figures are current at generation time.

Schema v4 snapshots company name, address, contacts and customer name, phone, and address when a new invoice is created. Reprints of those invoices use issuance-time identity. Earlier invoices keep null identity snapshots and use the customer's and company's current records as a documented legacy fallback; migration does not pretend those current values were captured historically. Existing financial records are never rewritten during generation.

## Platform validation

Automated checks validate page dimensions, actual-size A4 layout, content, payment states, pagination, logo fallback, database immutability, and generation after restart. The macOS desktop build verifies compatible Flutter APIs.

Before Windows deployment, test with the actual shop printer:

1. Installed-printer discovery and selection.
2. Native A5 tray/media support.
3. A4 centered and top-left placement at 100% scale.
4. Printable margins and physical clipping.
5. Multiple copies and printer cancellation/error behavior.
6. A paid invoice reprint with the current balance and “Balance as of” timestamp.

Opening a print dialog or producing a PDF is not evidence that a physical printer completed a job.
